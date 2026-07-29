import os
import json
import requests
from bs4 import BeautifulSoup
import firebase_admin
from firebase_admin import credentials, firestore
from dotenv import load_dotenv
from datetime import datetime

load_dotenv()

# Initialize Firebase
def initialize_firebase():
    # Priority 1: Environment Variable (for GitHub Actions/Heroku)
    firebase_creds_json = os.getenv('FIREBASE_SERVICE_ACCOUNT')

    if firebase_creds_json:
        creds_dict = json.loads(firebase_creds_json)
        cred = credentials.Certificate(creds_dict)
    else:
        # Priority 2: Local File
        service_account_path = os.path.join(os.path.dirname(__file__), 'serviceAccountKey.json')
        if os.path.exists(service_account_path):
            cred = credentials.Certificate(service_account_path)
        else:
            raise FileNotFoundError("Firebase credentials not found. Set FIREBASE_SERVICE_ACCOUNT or provide serviceAccountKey.json")

    firebase_admin.initialize_app(cred)
    return firestore.client()

def scrape_court_date(district, case_type, case_number, case_year):
    try:
        district_lower = district.lower().strip()
        # Punjab District Courts search URL
        url = f"https://{district_lower}.dc.lhc.gov.pk/case_info/case_search"

        payload = {
            'case_type': case_type or '',
            'case_number': case_number,
            'case_year': case_year,
            'submit': 'Search'
        }

        headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
            'Content-Type': 'application/x-www-form-urlencoded'
        }

        response = requests.post(url, data=payload, headers=headers, timeout=15)
        response.raise_for_status()

        soup = BeautifulSoup(response.text, 'lxml')

        # Searching for date in tables
        scraped_date = None

        # Logic 1: Find row containing "Next Date"
        for row in soup.find_all('tr'):
            text = row.get_text().lower()
            if 'next date' in text or 'hearing date' in text:
                cols = row.find_all('td')
                if cols:
                    scraped_date = cols[-1].get_text().strip()
                    break

        # Logic 2: If not found, try searching for "Next Date" label directly
        if not scraped_date:
            label = soup.find(text=lambda t: t and 'Next Date' in t)
            if label:
                parent = label.find_parent('td')
                if parent:
                    sibling = parent.find_next_sibling('td')
                    if sibling:
                        scraped_date = sibling.get_text().strip()

        return scraped_date
    except Exception as e:
        print(f"Error scraping {district} {case_number}/{case_year}: {e}")
        return None

def main():
    db = initialize_firebase()
    print("Firebase initialized. Fetching cases...")

    # Collection name should match your app (using 'Case request' as found in your Flutter code)
    collection_name = 'Case request'
    cases_ref = db.collection(collection_name)
    docs = cases_ref.where('courtName', '==', 'District Judiciary Punjab').stream()

    stats = {"processed": 0, "updated": 0, "errors": 0}

    for doc in docs:
        stats["processed"] += 1
        data = doc.to_dict()
        case_id = doc.id

        district = data.get('district')
        case_type = data.get('caseType')
        case_number = data.get('caseNumber')
        case_year = data.get('caseYear')
        current_date = data.get('nextHearingDate')

        if not all([district, case_number, case_year]):
            print(f"Skipping {case_id}: Missing parameters.")
            continue

        print(f"Checking {district} | {case_number}/{case_year}...")

        new_date = scrape_court_date(district, case_type, case_number, case_year)

        if new_date and new_date != current_date:
            doc.reference.update({
                'nextHearingDate': new_date,
                'lastScrapedAt': firestore.SERVER_TIMESTAMP,
                'scrapingStatus': 'Updated'
            })
            stats["updated"] += 1
            print(f"-> UPDATED: {new_date}")
        else:
            doc.reference.update({
                'lastCheckedAt': firestore.SERVER_TIMESTAMP,
                'scrapingStatus': 'No Change' if new_date else 'Not Found'
            })
            print(f"-> No change or not found.")

    print(f"\nScraping Completed. Stats: {stats}")

if __name__ == "__main__":
    main()
