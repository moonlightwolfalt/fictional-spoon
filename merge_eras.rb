#!/usr/bin/env ruby
# frozen_string_literal: true
#
# merge_eras.rb — fill each era's missing assets from the other eras.
#
#   ruby merge_eras.rb              # copy missing files into every era
#   ruby merge_eras.rb --dry-run    # show what would be copied
#   ruby merge_eras.rb --era 2020   # only fill 2020 (repeatable)
#   ruby merge_eras.rb --undo       # remove every file this script copied in (if unchanged)
#
# Each era keeps its own files. A missing asset is first taken from the era's own test
# builds (LIVETEST, LIVETEST541, oldmope: same site, same capture date, same art). After
# that, for every file some era has and another lacks, the copy comes from the era closest
# in date (ties go to the older era, so nothing looks newer
# than it should). What was copied, and from where, is recorded in <era>/.merged-from.json.
#
# fetch_era_assets.rb treats merged-in files as still missing, so a real download from the
# era's own date replaces the borrowed copy when one turns up.

require "json"
require "fileutils"
require "digest"
require "optparse"
require "set"

ROOT = File.expand_path(__dir__)
ERAS = {
  "2017" => { folder: "mope_fixed_20170704", date: Time.utc(2017, 7, 4) },
  "2018" => { folder: "mope_fixed_20181111", date: Time.utc(2018, 11, 11) },
  "2019" => { folder: "mope_fixed_20191029", date: Time.utc(2019, 10, 29) },
  "2020" => { folder: "mope_fixed_20200321", date: Time.utc(2020, 3, 21) },
}.freeze
RECORD = ".merged-from.json"
# Each era's own entry points stay its own; editor/OS junk isn't worth spreading.
# Test builds of the site that each era carries, in order of preference.
SIBLING_DIRS = %w[LIVETEST LIVETEST541 oldmope].freeze
ASSET_ROOTS  = %w[img/ skins/ audio/].freeze
NEVER_COPY = %w[index.html client.js updates.txt robots.txt ads.txt].freeze
SKIP_EXT   = %w[.pdn .psd .ds_store].freeze

opts = { eras: [], dry: false, undo: false }
OptionParser.new do |o|
  o.banner = "Usage: ruby merge_eras.rb [--era YEAR] [--dry-run] [--undo]"
  o.on("--era YEAR") { |v| opts[:eras] << v }
  o.on("--dry-run") { opts[:dry] = true }
  o.on("--undo") { opts[:undo] = true }
end.parse!
opts[:eras] = ERAS.keys if opts[:eras].empty?
(opts[:eras] - ERAS.keys).each { |e| abort "Unknown era #{e}. Choose from #{ERAS.keys.join(', ')}" }

def era_dir(year) = File.join(ROOT, ERAS[year][:folder])
def record_path(year) = File.join(era_dir(year), RECORD)
def load_record(year) = File.exist?(record_path(year)) ? JSON.parse(File.read(record_path(year))) : {}

def save_record(year, rec)
  if rec.empty?
    FileUtils.rm_f(record_path(year))
  else
    File.write(record_path(year), JSON.pretty_generate(rec.sort.to_h) + "\n")
  end
end

def directory_listing?(path)
  File.basename(path) == "index.html" && File.size(path) < 200_000 &&
    File.read(path, 2048, encoding: "BINARY").to_s.include?("<title>Index of /")
end

# Files an era genuinely has: no stray http: folders, no dotfiles, nothing borrowed.
def own_files(year)
  dir = era_dir(year)
  borrowed = load_record(year)
  Dir.glob("**/*", base: dir).each_with_object({}) do |rel, h|
    next if rel.start_with?("http:") || rel.split("/").any? { |s| s.start_with?(".") }
    # Files filled from this era's own test builds are this era's art; only files borrowed
    # from another era are excluded.
    next if borrowed.key?(rel) && !borrowed[rel]["from"].to_s.start_with?("#{year}/")
    path = File.join(dir, rel)
    next unless File.file?(path) && File.size(path).positive?
    h[rel] = path
  end
end

def refresh_manifest
  fetcher = File.join(ROOT, "fetch_era_assets.rb")
  system(RbConfig.ruby, fetcher, "--manifest") if File.exist?(fetcher)
end

# ───────────────────────────── undo ─────────────────────────────

if opts[:undo]
  opts[:eras].each do |year|
    rec = load_record(year)
    removed = kept = 0
    rec.dup.each do |rel, info|
      path = File.join(era_dir(year), rel)
      if !File.file?(path)
        rec.delete(rel)
      elsif Digest::SHA1.file(path).hexdigest == info["sha1"]
        if opts[:dry]
          puts "  would remove #{year}/#{rel}"
        else
          File.delete(path)
          # Tidy folders the merge created and left empty.
          d = File.dirname(path)
          while d.start_with?(era_dir(year) + "/") && Dir.empty?(d)
            Dir.rmdir(d)
            d = File.dirname(d)
          end
        end
        rec.delete(rel)
        removed += 1
      else
        kept += 1 # edited or replaced since — leave it, stop tracking it
        rec.delete(rel)
      end
    end
    save_record(year, rec) unless opts[:dry]
    puts "#{year}: removed #{removed} merged file(s)#{kept.positive? ? ", kept #{kept} that changed since" : ''}"
  end
  refresh_manifest unless opts[:dry]
  exit
end

# ───────────────────────────── merge ─────────────────────────────

# Pass 1: fill an era's main folders from its own test builds.
opts[:eras].each do |year|
  dir = era_dir(year)
  rec = load_record(year)
  copied = Hash.new(0)
  planned = Set.new
  SIBLING_DIRS.each do |sub|
    base = File.join(dir, sub)
    next unless File.directory?(base)
    Dir.glob("**/*", base: base).sort.each do |rel|
      next unless ASSET_ROOTS.any? { |r| rel.start_with?(r) }
      next if SKIP_EXT.include?(File.extname(rel).downcase) || rel.split("/").any? { |p| p.start_with?(".") }
      src = File.join(base, rel)
      next unless File.file?(src) && File.size(src).positive?
      dest = File.join(dir, rel)
      next if File.exist?(dest) || File.file?(File.dirname(dest)) || planned.include?(rel)
      next if directory_listing?(src)
      planned << rel
      copied[sub] += 1
      next if opts[:dry] && (puts "  #{year} ← #{year}/#{sub}  #{rel}"; true)
      FileUtils.mkdir_p(File.dirname(dest))
      FileUtils.cp(src, dest)
      # If the test-build file was itself borrowed from another era, keep that provenance.
      origin = rec["#{sub}/#{rel}"]&.dig("from") || "#{year}/#{sub}"
      rec[rel] = { "from" => origin, "sha1" => Digest::SHA1.file(dest).hexdigest }
    end
  end
  save_record(year, rec) unless opts[:dry]
  total = copied.values.sum
  puts "#{year}: #{opts[:dry] ? 'would copy' : 'copied'} #{total} file(s) from its own test builds" \
       "#{total.positive? ? " (#{copied.map { |k, v| "#{v} from #{k}" }.join(', ')})" : ''}"
end

# Pass 2: fill from other eras.
owned = ERAS.keys.to_h { |y| [y, own_files(y)] }
all_rels = owned.values.flat_map(&:keys).uniq

opts[:eras].each do |year|
  rec = load_record(year)
  dir = era_dir(year)
  # Other eras, closest first; ties go to the older one.
  donors = (ERAS.keys - [year]).sort_by do |y|
    gap = (ERAS[y][:date] - ERAS[year][:date]).abs
    [gap, ERAS[y][:date]]
  end

  copied = Hash.new(0)
  all_rels.each do |rel|
    next if owned[year].key?(rel) || rec.key?(rel)
    next if NEVER_COPY.include?(rel) || SKIP_EXT.include?(File.extname(rel).downcase)
    next if File.exist?(File.join(dir, rel)) # something is already there
    donor = donors.find { |y| owned[y].key?(rel) } or next
    src = owned[donor][rel]
    next if directory_listing?(src)

    dest = File.join(dir, rel)
    if File.file?(File.dirname(dest))
      warn "  skip #{year}/#{rel}: #{File.dirname(rel)} is a file in this era"
      next
    end
    copied[donor] += 1
    next if opts[:dry] && (puts "  #{year} ← #{donor}  #{rel}"; true)

    FileUtils.mkdir_p(File.dirname(dest))
    FileUtils.cp(src, dest)
    rec[rel] = { "from" => donor, "sha1" => Digest::SHA1.file(dest).hexdigest }
  end

  save_record(year, rec) unless opts[:dry]
  total = copied.values.sum
  from = copied.sort.map { |y, n| "#{n} from #{y}" }.join(", ")
  puts "#{year}: #{opts[:dry] ? 'would copy' : 'copied'} #{total} file(s)#{total.positive? ? " (#{from})" : ''}" \
       "#{rec.empty? ? '' : " — #{rec.size} borrowed in total"}"
end

refresh_manifest unless opts[:dry]
