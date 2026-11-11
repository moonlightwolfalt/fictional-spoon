#!/usr/bin/env ruby
# frozen_string_literal: true
#
# fetch_era_assets.rb — pull every animal, skin, ability, game-mode button, game object
# and audio file each era's client actually uses, from the Wayback Machine.
#
#   ruby fetch_era_assets.rb                       # all eras, all categories, 65 threads
#   ruby fetch_era_assets.rb --era 2020 --only skins,animals
#   ruby fetch_era_assets.rb --era 2018 --only modes
#   ruby fetch_era_assets.rb --only abilities      # abilities for all 4 eras
#   ruby fetch_era_assets.rb --dry-run             # print the plan per category, download nothing
#
# Options:
#   --era YEAR            2017, 2018, 2019 or 2020 (repeatable; default all)
#   --only LIST           comma list of: animals,skins,abilities,modes,objects,audio,ui
#   --concurrency N       download threads (default 65)
#   --strict              only use captures from on/before the era date (no later fallbacks)
#   --no-probe            don't try client-referenced files that the CDX index doesn't list
#   --refresh-index       re-download the Wayback CDX index instead of using .cache/
#   --force               re-download files that already exist
#   --dry-run             show what would be fetched
#   --stats               print how many files Wayback holds per category and era, then exit
#   --everything          give every era every archived image/sound, whatever its capture date
#   --manifest            only rewrite eras-manifest.json (local asset counts for the era selector)
#
# How it decides what to fetch:
#   1. Decode each era's client.js (the 2018–2020 clients hide strings as base64 in an
#      obfuscated array) and collect every string: paths, stems like "arctic/polarbear",
#      food names like "img/banana", folders like "skins/toucan/".
#   2. Expand those into candidate URLs using the client's own naming rules:
#        skins/<stem>.png, img/<name>.png, img/<name>_e.png (edible outline),
#        biome variants (_ocean/_arctic/_desert/_lava), audio/<name>.mp3, …
#      and treat every folder the client loads from as "everything archived under it"
#      (that is what catches numbered shop-skin variants and animation frames).
#   3. Intersect with the Wayback CDX index of all mope.io captures. Over-generating is
#      free: a candidate that was never archived is dropped before any download.
#   4. For each file pick the newest capture on/before the era date, else the nearest
#      later one (unless --strict), and download with N threads sharing one backoff gate.
#
# Writes <era>/.assets-report.json with per-category counts and what is still missing.

require "net/http"
require "uri"
require "json"
require "fileutils"
require "optparse"
require "set"

ROOT  = File.expand_path(__dir__)
CACHE = File.join(ROOT, ".cache")
WAYBACK = (ENV["WAYBACK"] || "https://web.archive.org").chomp("/") # override for testing
UA = "Mozilla/5.0 (compatible; era-asset-fetcher/1.0)"

ERAS = {
  "2017" => { folder: "mope_fixed_20170704", ts: "20170704235959" },
  "2018" => { folder: "mope_fixed_20181111", ts: "20181111235959" },
  "2019" => { folder: "mope_fixed_20191029", ts: "20191029235959" },
  "2020" => { folder: "mope_fixed_20200321", ts: "20200321235959" },
}.freeze

CATEGORIES = %w[animals skins abilities modes objects audio ui].freeze
HOST_RE    = /\A(?:www\.)?mope\.io\.?(?::\d+)?\z/i
ASSET_EXT  = %w[png jpg jpeg gif svg webp ico mp3 ogg wav m4a css js json txt html xml woff woff2 ttf].freeze
MEDIA_EXT  = %w[.png .jpg .jpeg .gif .svg .webp .ico .mp3 .ogg .wav .m4a .woff .woff2 .ttf].freeze
BIOME_SUFFIXES = ["", "_ocean", "_arctic", "_desert", "_lava", "_volcano", "_land"].freeze
# Folders too broad to expand wholesale (they'd pull in assets from other eras).
NO_EXPAND = %w[skins/ img/ audio/ skins/zombie/ skins/winter/ skins/santa/ skins/arctic/ skins/desert/ skins/land/ skins/ocean/ img/desert/].freeze

# ───────────────────────────── options ─────────────────────────────

opts = { eras: [], only: CATEGORIES, concurrency: 65, strict: false, probe: true,
         refresh: false, force: false, dry: false, everything: false, stats: false, manifest: false }
OptionParser.new do |o|
  o.banner = "Usage: ruby fetch_era_assets.rb [options]"
  o.on("--era YEAR") { |v| opts[:eras] << v }
  o.on("--only LIST") { |v| opts[:only] = v.split(",").map(&:strip) }
  o.on("--concurrency N", Integer) { |v| opts[:concurrency] = [v, 1].max }
  o.on("--strict") { opts[:strict] = true }
  o.on("--no-probe") { opts[:probe] = false }
  o.on("--refresh-index") { opts[:refresh] = true }
  o.on("--force") { opts[:force] = true }
  o.on("--dry-run") { opts[:dry] = true }
  o.on("--everything") { opts[:everything] = true }
  o.on("--stats") { opts[:stats] = true }
  o.on("--manifest") { opts[:manifest] = true }
  o.on("-h", "--help") { puts File.read(__FILE__)[/^# fetch_era_assets.*?(?=^require)/m].gsub(/^# ?/, ""); exit }
end.parse!

opts[:eras] = ERAS.keys if opts[:eras].empty?
(opts[:eras] - ERAS.keys).each { |e| abort "Unknown era #{e}. Choose from #{ERAS.keys.join(', ')}" }
(opts[:only] - CATEGORIES).each { |c| abort "Unknown category #{c}. Choose from #{CATEGORIES.join(', ')}" }

# ───────────────────────────── HTTP ─────────────────────────────

# One gate shared by every thread: on a 429 everyone waits, instead of 65 threads
# each hammering Wayback with their own retry.
class Gate
  def initialize = (@m = Mutex.new; @until = 0.0)
  def wait
    loop do
      t = @m.synchronize { @until - Process.clock_gettime(Process::CLOCK_MONOTONIC) }
      break if t <= 0
      sleep(t)
    end
  end
  def pause(seconds)
    @m.synchronize do
      target = Process.clock_gettime(Process::CLOCK_MONOTONIC) + seconds
      @until = target if target > @until
    end
  end
end
GATE = Gate.new
LOG  = Mutex.new
def log(msg) = LOG.synchronize { $stdout.puts(msg); $stdout.flush }

# Per-thread keep-alive connections, keyed by host.
def conn_for(uri)
  pool = (Thread.current[:conns] ||= {})
  key = "#{uri.scheme}://#{uri.host}:#{uri.port}"
  c = pool[key]
  return c if c&.started?
  c = Net::HTTP.new(uri.host, uri.port) # proxy comes from https_proxy / http_proxy env
  c.use_ssl = uri.scheme == "https"
  c.open_timeout = 20
  c.read_timeout = 120
  c.keep_alive_timeout = 30
  c.start
  pool[key] = c
end

def drop_conn(uri)
  pool = Thread.current[:conns] || {}
  key = "#{uri.scheme}://#{uri.host}:#{uri.port}"
  (pool.delete(key)&.finish rescue nil)
end

# Returns [status, body, final_url, content_type] or nil after retries.
def http_get(url, tries: 6)
  tries.times do |attempt|
    GATE.wait
    uri = URI(url)
    redirects = 0
    begin
      loop do
        req = Net::HTTP::Get.new(uri)
        req["User-Agent"] = UA
        req["Accept-Encoding"] = "identity"
        res = conn_for(uri).request(req)
        if res.is_a?(Net::HTTPRedirection) && res["location"] && redirects < 8
          redirects += 1
          uri = URI.join(uri.to_s, res["location"])
          next
        end
        code = res.code.to_i
        if code == 429
          wait = 30 * (attempt + 1)
          log "    ⏳ 429 from Wayback — all threads pausing #{wait}s"
          GATE.pause(wait)
          break
        elsif code >= 500
          sleep((2**attempt) * 1.5 + rand)
          break
        end
        return [code, res.body || "", uri.to_s, res["content-type"].to_s]
      end
    rescue StandardError => e
      drop_conn(uri)
      log "    ⚠️  #{e.class}: #{e.message[0, 120]} (#{url[-70..] || url})" if attempt == tries - 1
      sleep((2**attempt) * 1.5 + rand)
    end
  end
  nil
end

# Run a block over items with N threads.
def parallel(items, threads)
  q = Queue.new
  items.each { |i| q << i }
  threads = [[threads, items.size].min, 1].max
  Array.new(threads) do
    Thread.new do
      while (item = (q.pop(true) rescue nil))
        yield item
      end
      (Thread.current[:conns] || {}).each_value { |c| c.finish rescue nil }
    end
  end.each(&:join)
end

# ───────────────────────────── paths ─────────────────────────────

# URL or path -> clean era-relative path ("img/x.png"); nil if not ours.
def normalize(raw)
  s = raw.to_s.strip
  return nil if s.empty? || s.start_with?("data:", "blob:", "javascript:", "#")
  if (m = s.match(%r{\A(?:https?:)?//([^/?#]+)(/[^?#]*)?}i))
    return nil unless HOST_RE.match?(m[1])
    s = m[2] || "/"
  elsif s.match?(/\A[a-z][a-z0-9+.-]*:/i)
    return nil
  end
  s = s.split(/[?#]/).first.to_s
  s = URI.decode_www_form_component(s.gsub("+", "%2B")) rescue s
  dir = s.end_with?("/")
  parts = []
  s.split("/").each do |seg|
    next if seg.empty? || seg == "."
    return nil if seg == ".."
    parts << seg
  end
  rel = parts.join("/")
  rel = rel.empty? ? "index.html" : "#{rel}/index.html" if dir || rel.empty?
  rel
end

def category(rel)
  r = rel.downcase
  ext = File.extname(r)
  segs = r.split("/")
  return "audio"     if r.start_with?("audio/") || %w[.mp3 .ogg .wav .m4a].include?(ext)
  return "abilities" if r.include?("ability")
  return "modes"     if r.match?(%r{img/(mode_|icons/|update/)|1v1|teaser|battleroyale|/br\.png|gamemode|sandbox})
  return "ui"        if !MEDIA_EXT.include?(ext)
  if segs.first == "skins"
    base = File.basename(r, ext).sub(/\d+\z/, "")
    parent = segs[-2]
    # skins/<animal>.png, skins/<biome>/<animal>.png, skins/<animal>/<animal>.png = the animal itself
    return "animals" if segs.size == 2 ||
                        (segs.size == 3 && %w[arctic desert land ocean].include?(segs[1])) ||
                        base == parent
    return "skins"
  end
  "objects"
end

# ───────────────────────────── client decoding ─────────────────────────────

B64 = %r{\A[A-Za-z0-9+/]{4,}={0,2}\z}

def client_strings(path)
  src = File.read(path, encoding: "UTF-8").scrub("")
  out = []
  src.scan(/'((?:[^'\\\n]|\\.)*)'|"((?:[^"\\\n]|\\.)*)"/) do |a, b|
    s = (a || b).gsub(/\\x([0-9a-f]{2})/i) { Regexp.last_match(1).hex.chr }.gsub(/\\(.)/, '\1')
    out << s
    if s.length % 4 == 0 && B64.match?(s)
      d = s.unpack1("m").force_encoding("UTF-8")
      out << d if d.valid_encoding? && d.match?(/\A[[:print:]\n\t]*\z/)
    end
  end
  out.uniq
end

# Expand client strings into [exact candidates, folder prefixes].
def candidates_from(strings)
  exact = Set.new
  dirs  = Set.new
  ext_re = /\.(#{ASSET_EXT.join('|')})\z/i

  add_stem = lambda do |stem|
    BIOME_SUFFIXES.each do |b|
      exact << "#{stem}#{b}.png"
      exact << "#{stem}#{b}_e.png"
    end
    exact << "#{stem}.jpg" << "#{stem}.gif" << "#{stem}.mp3"
  end

  strings.each do |raw|
    next if raw.length > 160 || raw.match?(/\s{2}|[<>{}();=]/)
    # Absolute mope.io URLs embedded anywhere
    raw.scan(%r{(?:https?:)?//(?:www\.)?mope\.io(?::\d+)?/[^\s"'`()<>\\]*}i) { |u| (n = normalize(u)) && exact << n }

    s = raw.sub(%r{\A\./}, "")
    next if s.empty? || s.start_with?("/") && !s.match?(%r{\A/(img|skins|audio)/}) # "/mouth/stem.png" is a suffix fragment
    s = s.sub(%r{\A/}, "")
    next unless s.match?(%r{\A[A-Za-z0-9_\-./]+\z})

    if s.end_with?("/")
      dirs << s if s.count("/") >= 1 && s.length > 2
      next
    end

    if s.match?(ext_re)
      exact << s
      exact << "skins/#{s}" << "img/#{s}" unless s.start_with?("skins/", "img/", "audio/") || !s.include?("/")
      exact << "img/#{s}" << "skins/#{s}" << "audio/#{s}" unless s.include?("/")
      next
    end

    # Bare stems: "img/banana", "arctic/polarbear", "desert/gazelle/gazelle", "mouse"
    if s.start_with?("img/", "skins/", "audio/")
      add_stem.(s)
      dirs << "#{File.dirname(s)}/" if s.count("/") >= 2
    elsif s.include?("/")
      add_stem.("skins/#{s}")
      add_stem.("img/#{s}")
      dirs << "skins/#{File.dirname(s)}/" << "skins/#{s}/"
    elsif s.match?(/\A[a-zA-Z][a-zA-Z0-9_\-]{2,40}\z/)
      add_stem.("skins/#{s}")
      add_stem.("img/#{s}")
      exact << "audio/#{s}.mp3"
      dirs << "skins/#{s}/"
    end
  end
  [exact, dirs]
end

# ───────────────────────────── CDX index ─────────────────────────────

# { rel => [[timestamp, original, main], ...] } for every 200 capture of mope.io and its
# subdomains (beta.mope.io etc. served the same asset folders), all time. main is 1 for
# mope.io / www.mope.io captures and 0 for other subdomains.
def cdx_index(opts)
  FileUtils.mkdir_p(CACHE)
  cache = File.join(CACHE, "cdx-all-time-v2.json")
  if !opts[:refresh] && File.exist?(cache)
    data = JSON.parse(File.read(cache))
    log "📇 CDX index: cached (#{data.size} paths) — pass --refresh-index to rebuild"
    return data
  end

  rows = Queue.new
  %w[mope.io].each do |prefix|
    base = { "url" => prefix, "matchType" => "domain", "output" => "json",
             "fl" => "original,timestamp,digest", "filter" => "statuscode:200" }
    pages_res = http_get("#{WAYBACK}/cdx/search/cdx?#{URI.encode_www_form(base.merge('showNumPages' => 'true'))}")
    pages = pages_res && pages_res[0] == 200 ? pages_res[1].to_i : 0
    pages = 1 if pages <= 0
    log "📇 CDX index: #{prefix} — #{pages} page(s)"
    done = 0
    parallel((0...pages).to_a, [opts[:concurrency], 65].min) do |page|
      r = http_get("#{WAYBACK}/cdx/search/cdx?#{URI.encode_www_form(base.merge('page' => page.to_s))}")
      if r.nil? || r[0] != 200
        log "  ⚠️  CDX page #{page} failed (#{r&.first || 'no response'})"
        next
      end
      body = r[1].strip
      next if body.empty?
      JSON.parse(body).drop(1).each { |row| rows << row } rescue log("  ⚠️  CDX page #{page}: bad JSON")
      done += 1
      log "  · CDX #{prefix} page #{done}/#{pages}" if (done % 10).zero? || done == pages
    end
  end

  index = Hash.new { |h, k| h[k] = {} }
  until rows.empty?
    original, ts, digest = rows.pop
    m = original.match(%r{\A(?:https?:)?//([^/?#]+)(/[^#]*)?}i) || original.match(%r{\A([^/?#]+)(/[^#]*)?})
    next unless m
    host = m[1].downcase.sub(/:\d+\z/, "").chomp(".")
    next unless host == "mope.io" || host.end_with?(".mope.io")
    rel = normalize(m[2] || "/") or next
    main = HOST_RE.match?(host) ? 1 : 0
    # Subdomains only count for real assets, not their own pages/API responses.
    next if main.zero? && !(MEDIA_EXT + %w[.css .js]).include?(File.extname(rel).downcase)
    index[rel][digest || ts] ||= [ts, original, main]
  end
  data = index.transform_values { |h| h.values.sort_by(&:first) }
  abort "CDX index came back empty — is web.archive.org reachable?" if data.empty?
  File.write(cache, JSON.generate(data))
  log "📇 CDX index: #{data.size} unique archived paths (cached to .cache/)"
  data
end

# Newest capture <= era ts, else the earliest after it (unless strict).
def pick_capture(caps, ts, strict)
  # Prefer the main site's captures; fall back to subdomains (beta.mope.io, …).
  main = caps.select { |c| c[2].to_i == 1 }
  caps = main unless main.empty?
  before = caps.select { |c| c[0] <= ts }
  return before.last unless before.empty?
  strict ? nil : caps.first
end

# ───────────────────────────── per era ─────────────────────────────

def local_path(era_dir, rel)
  p = File.join(era_dir, rel)
  File.directory?(p) ? File.join(p, "index.html") : p
end

# Files merge_eras.rb copied in from another era: present, but not this era's own copy.
BORROWED = Hash.new do |h, era_dir|
  f = File.join(era_dir, ".merged-from.json")
  h[era_dir] = File.exist?(f) ? (JSON.parse(File.read(f)) rescue {}) : {}
end

def have?(era_dir, rel)
  return false if BORROWED[era_dir].key?(rel) # fetch the era's real version over it
  p = local_path(era_dir, rel)
  File.file?(p) && File.size(p).positive?
end

def plan_era(year, index, opts)
  cfg = ERAS[year]
  era_dir = File.join(ROOT, cfg[:folder])
  client = File.join(era_dir, "client.js")
  strings = File.exist?(client) ? client_strings(client) : []
  # Page HTML/CSS reference assets too (buttons, promos, mode icons).
  Dir.glob(File.join(era_dir, "{index.html,*.css,LIVETEST*/index.html}")).each do |f|
    File.read(f, encoding: "UTF-8").scrub("").scan(/(?:src|href)\s*=\s*["']([^"']+)["']|url\(\s*["']?([^"')]+)/i) do |a, b|
      strings << (a || b)
    end
  end
  exact, dirs = candidates_from(strings)
  exact = Set.new(exact.filter_map { |c| normalize(c) })
  literal = Set.new(strings.map { |s| s.sub(%r{\A\.?/}, "") })

  # Case-insensitive lookup into the archive (Wayback lowercases keys, sites didn't).
  lower = {}
  index.each_key { |k| lower[k.downcase] ||= k }

  wanted = {}
  exact.each do |c|
    k = index.key?(c) ? c : lower[c.downcase]
    wanted[k] = :cdx if k
  end
  # Any media file captured on/before the era date was live on the site then: that is
  # how every mode button, ability and shop skin of the era gets in, even ones the
  # client builds from server data instead of naming them.
  index.each do |k, caps|
    next if wanted.key?(k) || !MEDIA_EXT.include?(File.extname(k).downcase)
    wanted[k] = :cdx if opts[:everything] || caps.first[0] <= cfg[:ts]
  end

  # Everything archived under a folder the client loads from (variants, frames, parts).
  expandable = Set.new(dirs.filter_map { |d| normalize(d)&.delete_suffix("index.html")&.downcase }) - NO_EXPAND
  index.each_key do |k|
    next if wanted.key?(k)
    segs = k.downcase.split("/")
    (1...segs.size).each do |depth|
      if expandable.include?(segs[0, depth].join("/") + "/")
        wanted[k] = :cdx
        break
      end
    end
  end

  jobs = []
  skipped_strict = []
  wanted.each_key do |rel|
    next unless opts[:only].include?(category(rel))
    next if !opts[:force] && have?(era_dir, rel)
    cap = pick_capture(index[rel], cfg[:ts], opts[:strict])
    if cap.nil?
      skipped_strict << rel
      next
    end
    jobs << { rel: rel, url: "#{WAYBACK}/web/#{cap[0]}id_/#{cap[1]}", ts: cap[0], cat: category(rel) }
  end

  # Client paths with an explicit extension that the index doesn't list: probe them anyway,
  # Wayback sometimes has captures the prefix index misses.
  if opts[:probe]
    exact.each do |c|
      next if wanted.key?(c) || lower.key?(c.downcase)
      next unless c.match?(%r{\A(img|skins|audio)/}) && literal.include?(c)
      next unless opts[:only].include?(category(c))
      next if !opts[:force] && have?(era_dir, c)
      jobs << { rel: c, url: "#{WAYBACK}/web/#{cfg[:ts]}id_/http://mope.io/#{c}", ts: nil, cat: category(c), probe: true }
    end
  end

  { year: year, era_dir: era_dir, ts: cfg[:ts], jobs: jobs, strict_skipped: skipped_strict, strings: strings.size }
end

def run_jobs(plan, opts)
  era_dir = plan[:era_dir]
  report = Hash.new { |h, k| h[k] = { "fetched" => 0, "failed" => [] } }
  later = []
  m = Mutex.new
  total = plan[:jobs].size
  n = 0

  parallel(plan[:jobs], opts[:concurrency]) do |job|
    r = http_get(job[:url])
    i = m.synchronize { n += 1 }
    tag = "[#{plan[:year]} #{i}/#{total}]"
    rel = job[:rel]
    if job[:probe] && r&.first == 404
      m.synchronize { (report[job[:cat]]["not_archived"] ||= []) << rel }
      next
    end
    if r.nil? || r[0] != 200
      m.synchronize { report[job[:cat]]["failed"] << rel }
      log "  ✖ #{tag} #{rel} (#{r ? "HTTP #{r[0]}" : 'no response'})"
      next
    end
    _code, body, final, ctype = r
    if body.empty? || (MEDIA_EXT.include?(File.extname(rel).downcase) && ctype.include?("text/html"))
      m.synchronize { report[job[:cat]]["failed"] << rel }
      log "  ✖ #{tag} #{rel} (Wayback served an error page)"
      next
    end
    dest = local_path(era_dir, rel)
    begin
      FileUtils.mkdir_p(File.dirname(dest))
      File.binwrite(dest, body)
    rescue SystemCallError => e
      m.synchronize { report[job[:cat]]["failed"] << rel }
      log "  ✖ #{tag} #{rel} (#{e.message})"
      next
    end
    got = final[%r{/web/(\d{14})}, 1]
    late = got && got > plan[:ts]
    m.synchronize do
      BORROWED[era_dir].delete(rel)
      report[job[:cat]]["fetched"] += 1
      later << "#{rel} @ #{got}" if late
    end
    log "  ✔ #{tag} #{job[:cat].ljust(9)} #{rel}#{late ? "  (later capture #{got[0, 8]})" : ''}"
  end

  out = {
    "era" => plan[:year],
    "categories" => report,
    "later_captures" => later.sort,
    "not_archived_before_era" => plan[:strict_skipped].sort,
  }
  File.write(File.join(era_dir, ".assets-report.json"), JSON.pretty_generate(out))
  # Real downloads replaced some borrowed copies: stop tracking those.
  rec_file = File.join(era_dir, ".merged-from.json")
  if File.exist?(rec_file)
    BORROWED[era_dir].empty? ? File.delete(rec_file) : File.write(rec_file, JSON.pretty_generate(BORROWED[era_dir]) + "\n")
  end
  out
end

# ───────────────────────────── main ─────────────────────────────

# Count what each era folder holds on disk, per category, for the era selector (index.html).
def write_manifest
  eras = ERAS.map do |year, cfg|
    dir = File.join(ROOT, cfg[:folder])
    counts = CATEGORIES.to_h { |c| [c, 0] }
    bytes = 0
    borrowed = BORROWED[dir].size
    if File.directory?(dir)
      Dir.glob("**/*", File::FNM_DOTMATCH, base: dir).each do |rel|
        next if rel.start_with?("http:") || rel.split("/").any? { |seg| seg.start_with?(".") }
        path = File.join(dir, rel)
        next unless File.file?(path)
        counts[category(rel)] += 1
        bytes += File.size(path)
      end
    end
    { "year" => year, "folder" => cfg[:folder], "counts" => counts,
      "total" => counts.values.sum, "bytes" => bytes, "borrowed" => borrowed }
  end
  out = { "generated" => Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ"), "categories" => CATEGORIES, "eras" => eras }
  File.write(File.join(ROOT, "eras-manifest.json"), JSON.pretty_generate(out) + "\n")
  log "🗂  eras-manifest.json: " + eras.map { |e| "#{e['year']} #{e['total']}" }.join(", ")
end

if opts[:manifest]
  write_manifest
  exit
end

index = cdx_index(opts)

if opts[:stats]
  # How much Wayback really holds, per category: all time, and captured by each era date.
  cols = ["all time"] + ERAS.keys
  counts = Hash.new { |h, k| h[k] = Hash.new(0) }
  index.each do |rel, caps|
    c = category(rel)
    counts[c]["all time"] += 1
    ERAS.each { |y, cfg| counts[c][y] += 1 if caps.any? { |cap| cap[0] <= cfg[:ts] } }
  end
  log "\n#{'category'.ljust(10)}#{cols.map { |c| c.rjust(9) }.join}"
  CATEGORIES.each { |c| log "#{c.ljust(10)}#{cols.map { |col| counts[c][col].to_s.rjust(9) }.join}" }
  log "#{'total'.ljust(10)}#{cols.map { |col| counts.values.sum { |h| h[col] }.to_s.rjust(9) }.join}"
  log "\n(columns per era = files with a capture on/before that era's date; --everything ignores dates)"
  exit
end
summary = []

opts[:eras].each do |year|
  plan = plan_era(year, index, opts)
  by_cat = plan[:jobs].group_by { |j| j[:cat] }
  log "\n━━━ #{year} (#{ERAS[year][:folder]}) — #{plan[:strings]} client strings ━━━"
  CATEGORIES.each do |c|
    next unless opts[:only].include?(c)
    log "  #{c.ljust(9)} #{(by_cat[c] || []).size} to fetch"
  end
  if opts[:dry]
    plan[:jobs].sort_by { |j| [j[:cat], j[:rel]] }.each { |j| log "    · #{j[:cat].ljust(9)} #{j[:rel]}#{j[:probe] ? '  (probe)' : ''}" }
    next
  end
  res = run_jobs(plan, opts)
  summary << res
end

unless opts[:dry]
  log "\n━━━ summary ━━━"
  summary.each do |r|
    parts = r["categories"].map { |c, v| "#{c} +#{v['fetched']}#{v['failed'].empty? ? '' : " (#{v['failed'].size} failed)"}" }
    log "  #{r['era']}: #{parts.empty? ? 'nothing missing' : parts.join(', ')}"
  end
end

write_manifest unless opts[:dry]
