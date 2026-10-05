import os
import json
import time
import requests

api_key = os.getenv("OPENFDA_API_KEY")

if not api_key:
    raise ValueError("OPENFDA_API_KEY is not set")

url = "https://api.fda.gov/drug/event.json"
reports = []

for skip in range(0, 10000, 1000):
    params = {
        "api_key": api_key,
        "limit": 1000,
        "skip": skip
    }

    response = requests.get(url, params=params)
    response.raise_for_status()

    data = response.json()
    reports.extend(data["results"])

    print(f"Downloaded {len(reports)} reports")
    time.sleep(0.5)

with open("fda_reports_raw.json", "w", encoding="utf-8") as file:
    json.dump(reports, file, ensure_ascii=False)

print("Done")
