#!/usr/bin/env node
// Builds the deployable static site into public/ (used by Sevalla's build step).
//
//   node scripts/build-site.mjs
//
// Copies the era selector, its asset manifest and the four era folders, leaving out
// what a visitor never needs: the fetch scripts, caches, the stray "http:" folders
// the old fetcher created (their files are already merged into place), dotfiles and
// editor source files (.pdn/.psd).

import { cp, rm, mkdir, readdir, stat } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const OUT = path.join(ROOT, "public");
const TOP_FILES = ["index.html", "eras-manifest.json"];
const SKIP_EXT = new Set([".pdn", ".psd"]);

const keep = (src) => {
  const rel = path.relative(ROOT, src);
  const parts = rel.split(path.sep);
  if (parts.some((p) => p.startsWith(".") || p === "http:" || p === "https:")) return false;
  return !SKIP_EXT.has(path.extname(src).toLowerCase());
};

await rm(OUT, { recursive: true, force: true });
await mkdir(OUT, { recursive: true });

for (const f of TOP_FILES) {
  await cp(path.join(ROOT, f), path.join(OUT, f)).catch((e) => {
    if (f === "index.html") throw e; // the manifest is optional; the selector copes without it
  });
}

const eras = (await readdir(ROOT)).filter((d) => /^mope_fixed_\d{8}$/.test(d)).sort();
if (!eras.length) throw new Error("No era folders (mope_fixed_YYYYMMDD) found");
for (const era of eras) {
  await cp(path.join(ROOT, era), path.join(OUT, era), { recursive: true, filter: keep });
}

// Report what was built.
let files = 0, bytes = 0;
const walk = async (dir) => {
  for (const e of await readdir(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) await walk(p);
    else { files++; bytes += (await stat(p)).size; }
  }
};
await walk(OUT);
console.log(`Built public/: ${eras.length} eras, ${files} files, ${(bytes / 1e6).toFixed(1)} MB`);
