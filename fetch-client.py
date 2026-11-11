import concurrent.futures
import requests
from pathlib import Path

# The absolute fastest way to get these 4 files
ERAS = {
    "20170704": "mope_fixed_20170704",
    "20181111": "mope_fixed_20181111",
    "20191029": "mope_fixed_20191029",
    "20200321": "mope_fixed_20200321"
}

def quick_grab(date, folder):
    # mope.io swapped from root to /js/ around 2018/2019
    # We'll check the most likely one for each date
    filename = "js/client.js" if int(date[:4]) >= 2018 else "client.js"
    url = f"https://web.archive.org/web/{date}id_/http://mope.io/{filename}"
    
    try:
        r = requests.get(url, timeout=5, verify=False)
        if r.status_code == 200:
            p = Path(folder) / filename
            p.parent.mkdir(parents=True, exist_ok=True)
            with open(p, "wb") as f:
                f.write(r.content)
            return f"✨ [GOT IT] {date} -> {folder}"
    except:
        pass
    return f"❌ [STILL BLOCKED] {date}"

if __name__ == "__main__":
    import urllib3
    urllib3.disable_warnings()
    
    print("⚡ Launching Turbo Recovery...")
    with concurrent.futures.ThreadPoolExecutor() as executor:
        results = [executor.submit(quick_grab, d, f) for d, f in ERAS.items()]
        for f in concurrent.futures.as_completed(results):
            print(f.result())