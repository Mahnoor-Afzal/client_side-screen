const express = require('express');
const admin = require('firebase-admin');
const axios = require('axios');
const cheerio = require('cheerio');
const dotenv = require('dotenv');
const cron = require('node-cron');

dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;

// Firebase Admin Initialization
let serviceAccount;
if (process.env.FIREBASE_SERVICE_ACCOUNT) {
    serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
} else {
    try {
        serviceAccount = require('./serviceAccountKey.json');
    } catch (e) {
        console.warn("serviceAccountKey.json not found. Ensure FIREBASE_SERVICE_ACCOUNT env var is set.");
    }
}

if (serviceAccount) {
    admin.initializeApp({
        credential: admin.credential.cert(serviceAccount)
    });
    console.log("Firebase Admin initialized successfully.");
}

const db = admin.firestore();

// Scraper Logic Function
async function runScraper() {
    console.log("Starting Scraper Job...");
    const stats = { processed: 0, updated: 0, errors: 0 };

    try {
        // Query cases needing update from District Judiciary Punjab
        // Note: Using 'cases' as requested in prompt, adjust to 'Case request' if needed
        const snapshot = await db.collection('cases')
            .where('courtName', '==', 'District Judiciary Punjab')
            .get();

        if (snapshot.empty) {
            console.log("No matching cases found.");
            return stats;
        }

        for (const doc of snapshot.docs) {
            stats.processed++;
            const data = doc.data();
            const { district, caseType, caseNumber, caseYear, nextHearingDate } = data;

            if (!district || !caseNumber || !caseYear) continue;

            try {
                // Construct URL for specific district
                const districtLower = district.toLowerCase().trim();
                const url = `https://${districtLower}.dc.lhc.gov.pk/case_info/case_search`;

                // Search Request (Usually POST on these portals)
                const response = await axios.post(url, new URLSearchParams({
                    'case_type': caseType || '',
                    'case_number': caseNumber,
                    'case_year': caseYear,
                    'submit': 'Search'
                }), {
                    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
                    timeout: 10000
                });

                const $ = cheerio.load(response.data);
                let scrapedDate = "";

                // Parsing logic for Punjab Judiciary portals
                $("table tr").each((i, el) => {
                    const rowText = $(el).text().toLowerCase();
                    if (rowText.includes("next date") || rowText.includes("hearing date")) {
                        scrapedDate = $(el).find("td").last().text().trim();
                    }
                });

                if (!scrapedDate) {
                    scrapedDate = $("td:contains('Next Date')").next().text().trim();
                }

                if (scrapedDate && scrapedDate !== nextHearingDate) {
                    await doc.ref.update({
                        nextHearingDate: scrapedDate,
                        lastScrapedAt: admin.firestore.FieldValue.serverTimestamp(),
                        scrapingStatus: "Updated"
                    });
                    stats.updated++;
                    console.log(`Updated Case ${doc.id}: New Date ${scrapedDate}`);
                } else {
                    await doc.ref.update({
                        lastCheckedAt: admin.firestore.FieldValue.serverTimestamp(),
                        scrapingStatus: scrapedDate ? "No Change" : "Not Found"
                    });
                }
            } catch (err) {
                stats.errors++;
                console.error(`Error processing case ${doc.id}:`, err.message);
            }
        }
    } catch (err) {
        console.error("Scraper Error:", err);
    }
    return stats;
}

// Routes
app.get('/', (req, res) => {
    res.send("Smart Legal Assistant Scraper Server is Running Live!");
});

app.get('/run-scraper', async (req, res) => {
    const results = await runScraper();
    res.json({
        message: "Scraper execution finished",
        results: results
    });
});

// Scheduled Task: Daily at 1:00 AM Pakistan Time (Asia/Karachi)
// Cron: 0 1 * * *
cron.schedule('0 1 * * *', () => {
    runScraper();
}, {
    scheduled: true,
    timezone: "Asia/Karachi"
});

app.listen(PORT, () => {
    console.log(`Server is running on port ${PORT}`);
});
