#!/usr/bin/env bun
/**
 * fetch-eras.ts — fill in missing assets for each era snapshot from the Wayback Machine.
 *
 *   bun fetch-eras.ts                 # all eras: merge strays, CDX sweep, crawl references
 *   bun fetch-eras.ts --era 2019      # just one era (repeatable: --era 2017 --era 2020)
 *   bun fetch-eras.ts --dry-run       # show what would be fetched, download nothing
 *   bun fetch-eras.ts --merge-only    # only fold the stray "http:/mope.io:80/..." folders into place
 *
 * Options:
 *   --concurrency N     parallel downloads per era (default 4; Wayback rate-limits hard)
 *   --no-cdx            skip the CDX index sweep
 *   --no-crawl          skip scanning html/css/js/directory listings for references
 *   --no-merge          skip merging stray http: folders
 *   --clean-strays      delete the stray http: folders after merging them
 *   --force             re-download files that already exist
 *   --refresh-cdx       ignore the cached CDX index in .cache/
 *
 * Phases per era:
 *   1. merge  – the old fetch.py saved files whose URL had a port / www / odd host under
 *               "<era>/http:/<host>/...". Those are copied to their real paths.
 *   2. cdx    – ask the Wayback CDX API for every mope.io URL captured up to the era date,
 *               keep the newest capture per URL, download whatever is missing locally.
 *   3. crawl  – scan every html/css/js/txt file (and Apache "Index of" listings) for asset
 *               paths, fetch the missing ones from the capture nearest the era date, and
 *               scan newly downloaded files too, until nothing new turns up.
 *
 * A report of what was fetched / still missing is written to <era>/.fetch-report.json.
 */

import { mkdir, readdir, stat, copyFile, rm } from "node:fs/promises";
import { existsSync, statSync } from "node:fs";
import path from "node:path";

// ───────────────────────────── config ─────────────────────────────

const ERAS: Record<string, { folder: string; ts: string }> = {
  "2017": { folder: "mope_fixed_20170704", ts: "20170704235959" },
  "2018": { folder: "mope_fixed_20181111", ts: "20181111235959" },
  "2019": { folder: "mope_fixed_20191029", ts: "20191029235959" },
  "2020": { folder: "mope_fixed_20200321", ts: "20200321235959" },
};

const HOST_RE = /^(?:www\.)?mope\.io\.?$/i; // mope.io, www.mope.io, Mope.io, mope.io.
const ASSET_EXT =
  "png|jpe?g|gif|svg|webp|ico|bmp|mp3|ogg|wav|m4a|aac|css|js|json|txt|html?|xml|woff2?|ttf|otf|eot|cur|pdn|psd|zip";
const TEXT_EXT = new Set([".html", ".htm", ".css", ".js", ".json", ".txt", ".xml", ""]);
const MEDIA_EXT = new Set([
  ".png", ".jpg", ".jpeg", ".gif", ".svg", ".webp", ".ico", ".bmp",
  ".mp3", ".ogg", ".wav", ".m4a", ".aac", ".woff", ".woff2", ".ttf", ".otf", ".eot",
]);
const UA = "Mozilla/5.0 (compatible; era-archive-fetcher/1.0)";
const ROOT = import.meta.dir;
const CACHE = path.join(ROOT, ".cache");
const WAYBACK = (Bun.env.WAYBACK ?? "https://web.archive.org").replace(/\/$/, ""); // override for testing

// ───────────────────────────── args ─────────────────────────────

const argv = Bun.argv.slice(2);
const flag = (n: string) => argv.includes(n);
const opt = (n: string) => {
  const i = argv.indexOf(n);
  return i >= 0 ? argv[i + 1] : undefined;
};
const eraArgs = argv.flatMap((a, i) => (a === "--era" ? [argv[i + 1]] : []));
const DRY = flag("--dry-run");
const FORCE = flag("--force");
const CONCURRENCY = Math.max(1, Number(opt("--concurrency") ?? 4));
const DO_MERGE = !flag("--no-merge");
const DO_CDX = !flag("--no-cdx") && !flag("--merge-only");
const DO_CRAWL = !flag("--no-crawl") && !flag("--merge-only");
const CLEAN_STRAYS = flag("--clean-strays");
const REFRESH_CDX = flag("--refresh-cdx");

if (flag("--help") || flag("-h")) {
  const src = await Bun.file(import.meta.path).text();
  console.log(src.split("*/")[0].replace(/^#!.*\n\/\*\*\n?/, "").replace(/^ \* ?/gm, ""));
  process.exit(0);
}

const selected = eraArgs.length ? eraArgs : Object.keys(ERAS);
for (const y of selected) {
  if (!ERAS[y]) {
    console.error(`Unknown era "${y}". Choose from: ${Object.keys(ERAS).join(", ")}`);
    process.exit(1);
  }
}

// ───────────────────────────── helpers ─────────────────────────────

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));
const isFile = (p: string) => { try { return statSync(p).isFile(); } catch { return false; } };
const isDir = (p: string) => { try { return statSync(p).isDirectory(); } catch { return false; } };

/** Turn a URL or path into a clean era-relative path ("img/x.png"), or null if not ours. */
function normalizeRel(raw: string, baseDir = ""): string | null {
  let s = raw.trim();
  if (!s || s.startsWith("data:") || s.startsWith("blob:") || s.startsWith("javascript:") || s.startsWith("#")) return null;

  // Absolute URL (http://, https://, //)
  const m = s.match(/^(?:https?:)?\/\/([^/?#]+)(\/[^?#]*)?/i);
  if (m) {
    const host = m[1].replace(/:\d+$/, "");
    if (!HOST_RE.test(host)) return null;
    s = m[2] ?? "/";
    baseDir = "";
  } else if (/^[a-z][a-z0-9+.-]*:/i.test(s)) {
    return null; // mailto:, etc.
  }

  s = s.split(/[?#]/)[0];
  try { s = decodeURIComponent(s); } catch { /* keep as-is */ }

  const trailingSlash = s.endsWith("/");
  let rel = s.startsWith("/") ? s.slice(1) : path.posix.join(baseDir, s);
  rel = path.posix.normalize(rel || ".");
  if (rel === "." || rel === "./") rel = "";
  if (rel.startsWith("..") || rel.includes("\0")) return null;
  rel = rel.replace(/^\.\//, "").replace(/\/+$/, "");
  if (!rel || trailingSlash) rel = rel ? `${rel}/index.html` : "index.html";
  if (rel.split("/").some((seg) => seg === "http:" || seg === "https:")) return null;
  return rel;
}

/** Where a rel path lives on disk, accounting for file/dir collisions. */
function diskPath(eraDir: string, rel: string): string {
  const p = path.join(eraDir, rel);
  return isDir(p) ? path.join(p, "index.html") : p;
}

function haveLocally(eraDir: string, rel: string): boolean {
  const p = diskPath(eraDir, rel);
  try { return statSync(p).isFile() && statSync(p).size > 0; } catch { return false; }
}

async function walk(dir: string, out: string[] = []): Promise<string[]> {
  for (const e of await readdir(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) await walk(p, out);
    else if (e.isFile()) out.push(p);
  }
  return out;
}

async function fetchWithRetry(url: string, tries = 6): Promise<Response | null> {
  for (let attempt = 0; attempt < tries; attempt++) {
    try {
      const res = await fetch(url, {
        headers: { "User-Agent": UA },
        redirect: "follow",
        signal: AbortSignal.timeout(90_000),
      });
      if (res.status === 429 || res.status >= 500) {
        const wait = res.status === 429 ? 20_000 * (attempt + 1) : 2 ** attempt * 1500;
        await res.body?.cancel();
        console.warn(`    ⏳ ${res.status} — waiting ${Math.round(wait / 1000)}s`);
        await sleep(wait + Math.random() * 1000);
        continue;
      }
      return res;
    } catch (e: any) {
      const wait = 2 ** attempt * 1500;
      if (attempt === tries - 1) console.warn(`    ⚠️  ${e?.name ?? "error"}: ${e?.message ?? e}`);
      await sleep(wait + Math.random() * 500);
    }
  }
  return null;
}

/** Extract candidate era-relative asset paths from a text file. */
function extractRefs(text: string, fileRel: string, topDirs: Set<string>): string[] {
  const ext = path.extname(fileRel).toLowerCase();
  // JS paths resolve against the page (era root), html/css against their own folder.
  const baseDir = ext === ".js" ? "" : path.posix.dirname(fileRel) === "." ? "" : path.posix.dirname(fileRel);
  const found = new Set<string>();
  const add = (r: string, base = baseDir) => {
    const n = normalizeRel(r, base);
    if (n) found.add(n);
  };

  // Apache directory listing: every href is a file or subfolder in this directory.
  const listing = text.match(/<title>\s*Index of (\/[^<]*)<\/title>/i);
  if (listing) {
    const dirRel = listing[1].replace(/^\/+|\/+$/g, "");
    for (const [, href] of text.matchAll(/<a\s+href="([^"]+)"/gi)) {
      if (href.startsWith("?") || href.startsWith("/") || href.startsWith("..")) continue;
      add(href, dirRel);
    }
    return [...found];
  }

  // Absolute mope.io URLs anywhere.
  for (const [u] of text.matchAll(/(?:https?:)?\/\/(?:www\.)?mope\.io(?::\d+)?\/[^\s"'`()<>\\]*/gi)) add(u);

  // Quoted or url()-wrapped relative paths with a known extension.
  const re = new RegExp(
    String.raw`["'\x60(=]\s*((?:\.{1,2}\/|\/)?[A-Za-z0-9_\-][A-Za-z0-9_\-.\/ %]*\.(?:${ASSET_EXT}))(?:[?#][^"'\x60)\s]*)?\s*["'\x60)]`,
    "gi",
  );
  for (const [, p] of text.matchAll(re)) {
    // JS bundles glue paths together ("skins/" + name + "_nohand.png"), so only trust
    // strings that start with a real top-level folder; fragments would just 404.
    if (ext === ".js") {
      const first = p.replace(/^\.?\//, "").split("/")[0];
      if (!p.includes("/") || !topDirs.has(first)) continue;
    }
    add(p);
  }
  return [...found];
}

// ───────────────────────────── phases ─────────────────────────────

async function mergeStrays(eraDir: string) {
  const strayRoot = path.join(eraDir, "http:");
  if (!existsSync(strayRoot)) return { copied: 0 };
  let copied = 0;
  const done = new Set<string>();

  const entries = await readdir(strayRoot, { withFileTypes: true });
  for (const e of entries) {
    const host = e.name.replace(/:\d+$/, "");
    if (!HOST_RE.test(host)) continue;
    const hostPath = path.join(strayRoot, e.name);

    // "http:/mope.io" saved as a plain file is the site's front page.
    const files = e.isFile() ? [[hostPath, "index.html"] as const] :
      (await walk(hostPath)).map((f) => [f, path.relative(hostPath, f).split(path.sep).join("/")] as const);

    for (const [src, relRaw] of files) {
      const rel = normalizeRel("/" + relRaw);
      if (!rel || path.basename(rel) === ".DS_Store" || done.has(rel)) continue;
      done.add(rel);
      if (haveLocally(eraDir, rel)) continue;
      const dest = diskPath(eraDir, rel);
      if (DRY) { console.log(`  🔀 would merge ${rel}`); copied++; continue; }
      try {
        await mkdir(path.dirname(dest), { recursive: true });
        await copyFile(src, dest);
        copied++;
      } catch (err: any) {
        console.warn(`  ⚠️  could not merge ${rel}: ${err.message}`);
      }
    }
  }

  if (CLEAN_STRAYS && !DRY) {
    await rm(strayRoot, { recursive: true, force: true });
    console.log(`  🧹 removed ${path.relative(ROOT, strayRoot)}`);
  }
  return { copied };
}

type Capture = { rel: string; original: string; ts: string };

async function cdxIndex(era: string, ts: string): Promise<Capture[]> {
  await mkdir(CACHE, { recursive: true });
  const cacheFile = path.join(CACHE, `cdx-${era}.json`);
  let rows: string[][] | null = null;

  if (!REFRESH_CDX && isFile(cacheFile)) {
    rows = await Bun.file(cacheFile).json();
    console.log(`  📇 CDX: using cached index (${rows!.length} rows)`);
  } else {
    // Both mope.io/* and www.mope.io/*; matchType=domain also catches ports.
    rows = [];
    for (const url of ["mope.io/*", "www.mope.io/*"]) {
      const q = new URLSearchParams({
        url, to: ts, output: "json", fl: "original,timestamp,mimetype", filter: "statuscode:200",
      });
      console.log(`  📇 CDX: querying ${url} up to ${ts.slice(0, 8)}…`);
      const res = await fetchWithRetry(`${WAYBACK}/cdx/search/cdx?${q}`);
      if (!res || !res.ok) {
        console.warn(`  ⚠️  CDX query failed for ${url} (${res?.status ?? "no response"})`);
        continue;
      }
      const text = await res.text();
      if (!text.trim()) continue;
      const data: string[][] = JSON.parse(text);
      rows.push(...data.slice(1));
      await sleep(3000);
    }
    if (rows.length) await Bun.write(cacheFile, JSON.stringify(rows));
  }

  // Keep the newest capture at or before the era date for each path.
  const best = new Map<string, Capture>();
  for (const [original, cts] of rows) {
    const rel = normalizeRel(original);
    if (!rel) continue;
    const prev = best.get(rel);
    if (!prev || cts > prev.ts) best.set(rel, { rel, original, ts: cts });
  }
  return [...best.values()];
}

type Job = { rel: string; url: string; via: "cdx" | "crawl" };

async function runEra(year: string) {
  const { folder, ts } = ERAS[year];
  const eraDir = path.join(ROOT, folder);
  await mkdir(eraDir, { recursive: true });
  console.log(`\n━━━ ${year}  (${folder}) ━━━`);

  const report = { era: year, folder, fetched: [] as string[], laterCapture: [] as string[], failed: {} as Record<string, string>, merged: 0 };

  if (DO_MERGE) {
    const { copied } = await mergeStrays(eraDir);
    report.merged = copied;
    console.log(`  🔀 merged ${copied} file(s) from stray http: folders`);
  }

  const seen = new Set<string>();
  const queue: Job[] = [];
  const enqueue = (rel: string, url: string, via: Job["via"]) => {
    if (seen.has(rel)) return;
    seen.add(rel);
    if (!FORCE && haveLocally(eraDir, rel)) return;
    queue.push({ rel, url, via });
  };
  const waybackUrl = (stamp: string, original: string) => `${WAYBACK}/web/${stamp}id_/${original}`;

  if (DO_CDX) {
    const caps = await cdxIndex(year, ts);
    for (const c of caps) enqueue(c.rel, waybackUrl(c.ts, c.original), "cdx");
    console.log(`  📇 CDX: ${caps.length} archived paths, ${queue.length} missing locally`);
  }

  const topDirs = new Set(["img", "skins", "audio", "sounds", "fonts", "css", "js", "icons", "adblockdet"]);
  for (const e of await readdir(eraDir, { withFileTypes: true })) if (e.isDirectory() && !e.name.startsWith(".") && e.name !== "http:") topDirs.add(e.name);

  const scanFile = async (abs: string) => {
    const rel = path.relative(eraDir, abs).split(path.sep).join("/");
    if (rel.startsWith("http:/") || rel.startsWith(".")) return;
    if (!TEXT_EXT.has(path.extname(abs).toLowerCase())) return;
    let text: string;
    try { text = await Bun.file(abs).text(); } catch { return; }
    if (text.length > 20_000_000) return;
    for (const ref of extractRefs(text, rel, topDirs)) enqueue(ref, waybackUrl(ts, `http://mope.io/${ref.replace(/(^|\/)index\.html$/, "$1")}`), "crawl");
  };

  if (DO_CRAWL) {
    const before = queue.length;
    for (const f of await walk(eraDir)) await scanFile(f);
    console.log(`  🔎 crawl: ${queue.length - before} more referenced path(s) missing`);
  }

  if (DRY) {
    for (const j of queue) console.log(`  · [${j.via}] ${j.rel}`);
    console.log(`  (dry run) ${queue.length} file(s) would be fetched`);
    return report;
  }

  // Download worker pool; newly saved text files are scanned and can add more jobs.
  let done = 0;
  const worker = async () => {
    while (queue.length) {
      const job = queue.shift()!;
      const res = await fetchWithRetry(job.url);
      done++;
      const tag = `[${done}/${done + queue.length}]`;
      if (!res) { report.failed[job.rel] = "no response"; console.log(`  ✖ ${tag} ${job.rel} (no response)`); continue; }
      if (!res.ok) {
        await res.body?.cancel();
        report.failed[job.rel] = `HTTP ${res.status}`;
        console.log(`  ✖ ${tag} ${job.rel} (HTTP ${res.status})`);
        continue;
      }

      const buf = new Uint8Array(await res.arrayBuffer());
      const ctype = res.headers.get("content-type") ?? "";
      const ext = path.extname(job.rel).toLowerCase();
      if (!buf.length) { report.failed[job.rel] = "empty"; continue; }
      if (MEDIA_EXT.has(ext) && ctype.includes("text/html")) {
        report.failed[job.rel] = "got HTML instead of media";
        console.log(`  ✖ ${tag} ${job.rel} (Wayback served an HTML page)`);
        continue;
      }

      const dest = diskPath(eraDir, job.rel);
      try {
        await mkdir(path.dirname(dest), { recursive: true });
        await Bun.write(dest, buf);
      } catch (err: any) {
        report.failed[job.rel] = `write: ${err.message}`;
        console.log(`  ✖ ${tag} ${job.rel} (${err.message})`);
        continue;
      }

      const got = res.url.match(/\/web\/(\d{14})/)?.[1];
      const late = got && got > ts;
      if (late) report.laterCapture.push(`${job.rel} @ ${got}`);
      report.fetched.push(job.rel);
      console.log(`  ✔ ${tag} ${job.rel}${late ? `  (nearest capture: ${got.slice(0, 8)})` : ""}`);

      if (DO_CRAWL) await scanFile(dest);
      await sleep(250);
    }
  };
  // Keep spinning workers while scanning keeps adding jobs.
  while (queue.length) await Promise.all(Array.from({ length: CONCURRENCY }, worker));

  await Bun.write(path.join(eraDir, ".fetch-report.json"), JSON.stringify(report, null, 2));
  const nFail = Object.keys(report.failed).length;
  console.log(`  ✅ ${year}: fetched ${report.fetched.length}, merged ${report.merged}, still missing ${nFail}` +
    (report.laterCapture.length ? `, ${report.laterCapture.length} from later captures` : ""));
  return report;
}

// ───────────────────────────── main ─────────────────────────────

const summary = [];
for (const y of selected) {
  summary.push(await runEra(y));
  if (!DRY && selected.length > 1) await sleep(3000);
}
console.log("\n━━━ summary ━━━");
for (const r of summary) {
  console.log(`  ${r.era}: +${r.fetched.length} fetched, +${r.merged} merged, ${Object.keys(r.failed).length} unavailable`);
}
