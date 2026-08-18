import os
import json
import requests
from bs4 import BeautifulSoup
import firebase_admin
from firebase_admin import credentials, firestore
from dotenv import load_dotenv
from datetime import datetime, timedelta
import re
import random
import time

load_dotenv()

# Set this to True to test with local sample_case.html instead of live website
IS_DUMMY_MODE = True

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

    if not firebase_admin._apps:
        firebase_admin.initialize_app(cred)
    return firestore.client()

def solve_math_captcha(html_content):
    """
    Extracts and solves math captcha like 'What is 5 + 3 =' or '7 - 2 ='
    """
    try:
        # Looking for common patterns in Pakistani gov portals
        match = re.search(r'(\d+)\s*([\+\-\*])\s*(\d+)', html_content)
        if match:
            n1, op, n2 = int(match.group(1)), match.group(2), int(match.group(3))
            if op == '+': return n1 + n2
            if op == '-': return n1 - n2
            if op == '*': return n1 * n2
    except Exception as e:
        print(f"Captcha Solver Error: {e}")
    return None

def scrape_court_date(district, case_type, case_number, case_year, court_name):
    # --- DUMMY MODE LOGIC ---
    if IS_DUMMY_MODE:
        print(f"[DUMMY MODE] Generating dynamic data for Case #{case_number}...")
        try:
            # Generate a random future date (today + 10 to 60 days)
            # We seed with the case number to make it consistent for the same case during a single run
            # random.seed(case_number)
            days_ahead = random.randint(10, 60)
            future_date = datetime.now() + timedelta(days=days_ahead)

            # Format: "12 Oct 2026"
            formatted_date = future_date.strftime("%d %b %Y")

            # Generate random hearing time
            random_time = random.choice(["09:00 AM", "10:30 AM", "11:30 AM", "01:30 PM", "02:00 PM"])

            # Static mock data for other fields
            return {
                'nextHearingDate': formatted_date,
                'hearingTime': random_time,
                'judgeName': "Mr. Usman Ali (Additional District Judge)",
                'caseStage': "Evidence / Cross Examination",
                'petitioner': "State vs Ahmad Khan",
                'respondent': "Defense Counsel",
                'found': True
            }
        except Exception as e:
            print(f"Dummy Mode Error: {e}")
            return {"found": False, "error": str(e)}

    # --- LIVE SCRAPER LOGIC ---
    session = requests.Session()
    base_url = "https://dsj.punjab.gov.pk"

    try:
        headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7',
            'Accept-Language': 'en-US,en;q=0.9',
        }
        response = session.get(base_url, headers=headers, timeout=15)
        response.raise_for_status()

        soup_init = BeautifulSoup(response.text, 'lxml')
        captcha_ans = solve_math_captcha(response.text)

        if captcha_ans is None:
            print(f"Could not find or solve captcha for {district}")
            return {"found": False, "error": "Captcha not found or solved"}

        form = soup_init.find('form', attrs={'action': re.compile(r'search|case|cause', re.I)}) or soup_init.find('form')
        if not form:
            print(f"No search form found on {base_url}")
            return {"found": False, "error": "Search form not found"}

        action = form.get('action') or ""
        search_url = f"{base_url}/{action.lstrip('/')}" if not action.startswith('http') else action

        payload = {}
        for hidden in form.find_all('input', type='hidden'):
            if hidden.get('name'):
                payload[hidden.get('name')] = hidden.get('value', '')

        payload.update({
            'district': district,
            'court_name': court_name,
            'case_type': case_type or '',
            'case_no': case_number,
            'case_year': case_year,
            'ans': str(captcha_ans),
            'submit': 'Search'
        })

        post_headers = headers.copy()
        post_headers['Content-Type'] = 'application/x-www-form-urlencoded'
        post_headers['Origin'] = base_url
        post_headers['Referer'] = response.url

        search_res = session.post(search_url, data=payload, headers=post_headers, timeout=15, allow_redirects=True)
        if search_res.status_code == 405:
            search_res = session.get(search_url, params=payload, headers=headers, timeout=15)

        search_res.raise_for_status()
        soup = BeautifulSoup(search_res.text, 'lxml')

        result_data = {
            'nextHearingDate': None,
            'judgeName': None,
            'caseStage': None,
            'petitioner': None,
            'respondent': None,
            'found': False
        }

        tables = soup.find_all('table')
        if not tables:
            return result_data

        for table in tables:
            rows = table.find_all('tr')
            for row in rows:
                row_text = row.get_text().lower()
                cols = row.find_all('td')
                if len(cols) < 2: continue

                result_data['found'] = True
                label = cols[0].get_text().strip().lower()
                value = cols[-1].get_text().strip()

                if 'judge' in label or 'court of' in label:
                    result_data['judgeName'] = value
                elif 'next date' in label or 'hearing date' in label:
                    result_data['nextHearingDate'] = value
                elif 'stage' in label or 'proceeding' in label:
                    result_data['caseStage'] = value
                elif 'petitioner' in label or 'plaintiff' in label:
                    result_data['petitioner'] = value
                elif 'respondent' in label or 'defendant' in label:
                    result_data['respondent'] = value
                elif 'vs' in row_text:
                    parts = re.split(r'\s+vs\.?\s+', row.get_text(), flags=re.IGNORECASE)
                    if len(parts) == 2:
                        result_data['petitioner'] = parts[0].strip()
                        result_data['respondent'] = parts[1].strip()

            if result_data['nextHearingDate']:
                break

        return result_data
    except Exception as e:
        print(f"Error scraping {district} {case_number}/{case_year}: {e}")
        return {"found": False, "error": str(e)}

# --- Professional Notification Sender Function ---
def create_hearing_notifications(db, case_doc_id, case_data, scraped_result):
    lawyer_id = case_data.get('lawyerId')
    client_id = case_data.get('clientId')
    client_name = case_data.get('clientName', 'Valued Client')
    case_number = case_data.get('caseNumber', 'N/A')
    court_name = case_data.get('courtName', 'District Court')

    hearing_date = scraped_result.get('nextHearingDate', 'N/A')
    hearing_time = scraped_result.get('hearingTime', '09:00 AM')
    judge_name = scraped_result.get('judgeName', 'Honorable Judge')

    notifications_ref = db.collection('notifications')

    # 1. Notification for LAWYER
    if lawyer_id:
        lawyer_msg = (
            f"Hearing Scheduled: Case #{case_number} ({client_name}) is set for "
            f"{hearing_date} at {hearing_time} before {judge_name}."
        )
        notifications_ref.add({
            'userId': lawyer_id,
            'role': 'lawyer',
            'caseId': case_doc_id,
            'title': f"Hearing Alert: Case #{case_number}",
            'message': lawyer_msg,
            'type': 'hearing_update',
            'isRead': False,
            'createdAt': firestore.SERVER_TIMESTAMP
        })

    # 2. Notification for CLIENT
    if client_id:
        client_msg = (
            f"Dear {client_name}, your court case #{case_number} ({court_name}) "
            f"has a new hearing date: {hearing_date} at {hearing_time}."
        )
        notifications_ref.add({
            'userId': client_id,
            'role': 'client',
            'caseId': case_doc_id,
            'title': f"Upcoming Hearing Update - Case #{case_number}",
            'message': client_msg,
            'type': 'hearing_update',
            'isRead': False,
            'createdAt': firestore.SERVER_TIMESTAMP
        })

    print(f"[{case_doc_id}] -> Professional notifications created for Lawyer and Client ({client_name}).")

def start_automated_scraper(interval_seconds=60):
    db = initialize_firebase()
    print(f"Automated Scraper Service Started (Interval: {interval_seconds}s)...")

    while True:
        try:
            print(f"\n[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] Checking for cases...")
            collection_name = 'cases'
            cases_ref = db.collection(collection_name)

            # Fetching cases where scrapingStatus is Pending
            docs = list(cases_ref.where('scrapingStatus', 'in', ['Pending']).stream())

            if not docs:
                print("No pending cases found.")
            else:
                stats = {"processed": 0, "updated": 0, "not_found": 0, "errors": 0}

                for doc in docs:
                    data = doc.to_dict()
                    doc_id = doc.id

                    # Only process Punjab District Judiciary or High Court (Demo) cases
                    court_name = data.get('courtName', '').lower()
                    if 'district' not in court_name and 'high' not in court_name:
                        continue

                    stats["processed"] += 1

                    district = data.get('district', 'Punjab')
                    case_type = data.get('caseType', '')
                    case_number = data.get('caseNumber')
                    case_year = data.get('caseYear')

                    if not all([case_number, case_year]):
                        print(f"[{doc_id}] Skipping: Missing case details.")
                        continue

                    print(f"[{doc_id}] Fetching: {district} | {case_number}/{case_year}...")

                    scraped_result = scrape_court_date(district, case_type, case_number, case_year, court_name)

                    if scraped_result and scraped_result.get('found'):
                        new_date = scraped_result.get('nextHearingDate')
                        existing_date = data.get('nextHearingDate')

                        update_data = {
                            'nextHearingDate': new_date or data.get('nextHearingDate', 'N/A'),
                            'hearingTime': scraped_result.get('hearingTime') or data.get('hearingTime', '09:00 AM'),
                            'judgeName': scraped_result.get('judgeName') or data.get('judgeName', 'N/A'),
                            'caseStage': scraped_result.get('caseStage') or data.get('caseStage', 'N/A'),
                            'petitioner': scraped_result.get('petitioner') or data.get('petitioner', 'N/A'),
                            'respondent': scraped_result.get('respondent') or data.get('respondent', 'N/A'),
                            'status': 'Active', # strictly "Active"
                            'scrapingStatus': 'Synced',
                            'updatedAt': firestore.SERVER_TIMESTAMP # standardized key
                        }

                        # Update hearing history if date has changed
                        if existing_date and new_date and existing_date != new_date and existing_date != 'N/A':
                            history_item = {
                                'hearingDate': existing_date,
                                'hearingTime': data.get('hearingTime', 'N/A'),
                                'judgeName': data.get('judgeName', 'N/A'),
                                'status': 'Completed'
                            }
                            update_data['hearingHistory'] = firestore.ArrayUnion([history_item])

                        try:
                            doc.reference.update(update_data)

                            try:
                                # Notification bhejna (Lawyer aur Client ko alert karne ke liye)
                                create_hearing_notifications(db, doc_id, data, scraped_result)
                            except Exception as e:
                                print(f"[{doc_id}] -> Notification Error: {e}")

                            stats["updated"] += 1
                            print(f"[{doc_id}] -> UPDATED successfully.")
                        except Exception as e:
                            stats["errors"] += 1
                            print(f"[{doc_id}] -> Update Error: {e}")
                    else:
                        print(f"[{doc_id}] -> NOT FOUND on portal.")
                        try:
                            doc.reference.update({
                                'scrapingStatus': 'Failed',
                                'updatedAt': firestore.SERVER_TIMESTAMP
                            })
                            stats["not_found"] += 1
                        except Exception as e:
                            print(f"[{doc_id}] -> Status Update Error: {e}")

                print(f"Batch completed. Stats: {stats}")

        except Exception as e:
            print(f"Loop Error: {e}")

        time.sleep(interval_seconds)

if __name__ == "__main__":
    start_automated_scraper(interval_seconds=60)
