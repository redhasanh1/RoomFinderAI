"""
Campaign heartbeat for the landlord push.

Polls the live listings API and records how many real, non-seed landlords
and listings exist, so we can see outreach converting rather than guessing.

The seed/test accounts are excluded deliberately: counting Hasan's own demo
listings as traction is the fastest way to lie to ourselves about whether
any of this is working.

Appends one row per run to growth/data/traction.csv. Safe to run on a timer.
"""
import csv
import datetime
import json
import os
import urllib.request

API = "https://www.roomfinderai.com/api/listings"
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "data", "traction.csv")

# Accounts that are ours, not the market's.
SEED = {
    "cryptocoins0@yahoo.com",
    "hasaniqbal2@hotmail.com",
    "rf.test.tenant.aug17@gmail.com",
    "rf.test.landlord2.aug20@gmail.com",
}

GTA = {"toronto", "north york", "scarborough", "etobicoke", "mississauga",
       "brampton", "oakville", "markham", "richmond hill", "vaughan",
       "hamilton", "waterloo", "guelph", "oshawa", "burlington", "milton"}


def fetch():
    req = urllib.request.Request(API, headers={"accept": "application/json",
                                               "user-agent": "roomfinderai-growth-monitor"})
    with urllib.request.urlopen(req, timeout=30) as r:
        data = json.loads(r.read().decode("utf-8"))
    if isinstance(data, dict):
        for k in ("listings", "data", "results"):
            if k in data:
                data = data[k]
                break
    return data if isinstance(data, list) else []


def main():
    try:
        rows = fetch()
    except Exception as exc:
        print("UNREACHABLE: %s" % exc)
        return 1

    real = [l for l in rows if (l.get("user_email") or "").lower() not in SEED]
    landlords = {(l.get("user_email") or "").lower() for l in real if l.get("user_email")}
    in_gta = [l for l in real if (l.get("location") or "").split(",")[0].strip().lower() in GTA]

    now = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    row = [now, len(rows), len(real), len(landlords), len(in_gta)]

    new_file = not os.path.exists(OUT)
    with open(OUT, "a", newline="", encoding="utf-8") as fh:
        w = csv.writer(fh)
        if new_file:
            w.writerow(["timestamp", "listings_total", "listings_real",
                        "landlords_real", "listings_gta"])
        w.writerow(row)

    print("%s  total=%d  real=%d  real_landlords=%d  gta=%d  (target 1000 landlords)"
          % (now, len(rows), len(real), len(landlords), len(in_gta)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
