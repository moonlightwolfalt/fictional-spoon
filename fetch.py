import asyncio
import aiohttp
import os
import random
from pathlib import Path

# SETTINGS
CONCURRENCY = 100 
TIMEOUT_SETTINGS = aiohttp.ClientTimeout(total=60, connect=15)

# Mapping folders to their strict timestamp limit
TARGET_ERAS = {
    "mope_fixed_20170704": "20170704235959",
    "mope_fixed_20181111": "20181111235959",
    "mope_fixed_20191029": "20191029235959",
    "mope_fixed_20200321": "20200321235959"
}

async def download_file(session, semaphore, url, timestamp, base_dir):
    async with semaphore:
        clean_path = url.split("mope.io/")[-1].split('?')[0]
        if not clean_path or clean_path.endswith("/"):
            clean_path = os.path.join(clean_path, "index.html")
        
        local_file = base_dir / clean_path
        local_file.parent.mkdir(parents=True, exist_ok=True)
        
        # 'id_' forces the raw file, bypassing the Wayback UI
        raw_url = f"https://web.archive.org/web/{timestamp}id_/{url}"

        for attempt in range(5):
            try:
                async with session.get(raw_url, timeout=TIMEOUT_SETTINGS) as response:
                    if response.status == 200:
                        content = await response.read()
                        if len(content) > 0:
                            with open(local_file, "wb") as f:
                                f.write(content)
                            # Log the year we actually pulled
                            print(f"  🚀 [ERA-FIX {timestamp[:4]}] -> {clean_path}")
                        return
                    elif response.status == 429:
                        await asyncio.sleep((2 ** attempt) + random.random())
            except Exception:
                await asyncio.sleep(1)

async def process_era(session, folder_name, to_ts, semaphore):
    folder_path = Path(folder_name)
    folder_path.mkdir(parents=True, exist_ok=True)
    
    print(f"\n--- 🛰️ ENFORCING CORRECT DATES FOR: {folder_name} ---")
    
    # We remove 'collapse' to see every version, then pick the latest one locally
    cdx_url = (
        f"https://web.archive.org/cdx/search/cdx?"
        f"url=mope.io/*&to={to_ts}&output=json"
        f"&fl=original,timestamp,statuscode"
    )
    
    try:
        async with session.get(cdx_url) as r:
            if r.status == 200:
                data = await r.json()
                rows = data[1:]
                
                # ERA ENFORCEMENT LOGIC:
                # We store the LATEST capture for every URL found up to the target date.
                # This ensures 2019 folders get 2019 files, not 2016 files.
                manifest = {}
                for url, ts, status in rows:
                    if status == "200":
                        manifest[url] = ts
                
                print(f"📦 Found {len(manifest)} assets. Forcing overwrite of old versions...")
                
                tasks = [download_file(session, semaphore, url, ts, folder_path) 
                         for url, ts in manifest.items()]
                await asyncio.gather(*tasks)
    except Exception as e:
        print(f"⚠️ CDX Error: {e}")

async def main():
    semaphore = asyncio.Semaphore(CONCURRENCY)
    conn = aiohttp.TCPConnector(limit=CONCURRENCY, ttl_dns_cache=600)
    
    async with aiohttp.ClientSession(connector=conn) as session:
        session.headers.update({
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0"
        })
        
        for folder_name, to_ts in TARGET_ERAS.items():
            await process_era(session, folder_name, to_ts, semaphore)
            print(f"✅ Era {folder_name} is now date-accurate.")
            await asyncio.sleep(5) # Cooldown to prevent IP bans

if __name__ == "__main__":
    asyncio.run(main())