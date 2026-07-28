const functions = require("firebase-functions");
const admin = require("firebase-admin");
const axios = require("axios");
const cheerio = require("cheerio");
const { DateTime } = require("luxon");

admin.initializeApp();
const db = admin.firestore();

/**
 * Core Scraping Logic
 * This function is shared by both the Cron Job and the HTTPS trigger.
 */
async function scrapeCourtDates() {
    // Correct collection name from your firestore_service.dart is 'Case request'
    const casesSnapshot = await db.collection("Case request")
        .where("courtName", "==", "District Judiciary Punjab")
        .get();

    if (casesSnapshot.empty) {
        console.log("No cases found for District Judiciary Punjab.");
        return { success: true, processed: 0 };
    }

    let updatedCount = 0;
    let errorCount = 0;

    for (const doc of casesSnapshot.docs) {
        const caseData = doc.data();
        const caseId = doc.id;

        // Skip if required fields are missing
        if (!caseData.district || !caseData.caseNumber || !caseData.caseYear) {
            console.log(`Skipping Case ${caseId}: Missing search parameters.`);
            continue;
        }

        try {
            console.log(`Processing Case: ${caseData.caseNumber}/${caseData.caseYear} - ${caseData.district}`);

            // 1. Construct the District-Specific Search URL
            const districtLower = caseData.district.toLowerCase().trim();
            // Note: Different districts might have slightly different subdomains
            const searchUrl = `https://${districtLower}.dc.lhc.gov.pk/case_info/case_search`;

            // 2. Perform the Search Request
            // This is a simulation of the POST request needed for the Punjab Judiciary search form
            const response = await axios.post(searchUrl, new URLSearchParams({
                'case_type': caseData.caseType || "",
                'case_number': caseData.caseNumber,
                'case_year': caseData.caseYear,
                'submit': 'Search'
            }), {
                headers: {
                    'Content-Type': 'application/x-form-urlencoded',
                    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
                },
                timeout: 10000
            });

            // 3. Parse HTML with Cheerio
            const $ = cheerio.load(response.data);
            let scrapedDate = "";

            // Scraping logic for Punjab District Courts table structure
            // Usually, the next date is found in a table or a specific summary div
            $("table tr").each((i, el) => {
                const text = $(el).text().toLowerCase();
                if (text.includes("next date") || text.includes("hearing date")) {
                    scrapedDate = $(el).find("td").last().text().trim();
                }
            });

            // Fallback: If table rows don't yield result, try finding by label
            if (!scrapedDate) {
                scrapedDate = $("td:contains('Next Date')").next().text().trim() ||
                              $("div:contains('Next Date')").next().text().trim();
            }

            // 4. Update Firestore if date is found and it is NEW
            if (scrapedDate && scrapedDate !== caseData.nextHearingDate) {
                await db.collection("Case request").doc(caseId).update({
                    nextHearingDate: scrapedDate,
                    lastScrapedAt: admin.firestore.FieldValue.serverTimestamp(),
                    scrapingStatus: "Success"
                });
                updatedCount++;
                console.log(`Successfully updated Case ${caseId} to ${scrapedDate}`);
            } else {
                // Just update the last checked timestamp
                await db.collection("Case request").doc(caseId).update({
                    lastCheckedAt: admin.firestore.FieldValue.serverTimestamp(),
                    scrapingStatus: scrapedDate ? "No Change" : "Not Found"
                });
            }

        } catch (error) {
            errorCount++;
            console.error(`Error scraping Case ${caseId}:`, error.message);
            await db.collection("Case request").doc(caseId).update({
                scrapingStatus: "Failed",
                lastScrapeError: error.message,
                lastCheckedAt: admin.firestore.FieldValue.serverTimestamp()
            });
        }
    }

    return {
        processed: casesSnapshot.size,
        updated: updatedCount,
        errors: errorCount,
        timestamp: DateTime.now().setZone("Asia/Karachi").toString()
    };
}

/**
 * Scheduled Function: Runs at 1:00 AM Pakistan Time every day
 */
exports.dailyCourtScraper = functions.pubsub
    .schedule("0 1 * * *")
    .timeZone("Asia/Karachi")
    .onRun(async (context) => {
        console.log("Starting Daily Scheduled Court Scraper...");
        return await scrapeCourtDates();
    });

/**
 * HTTPS Function: Allows you to trigger the scraper manually via URL
 */
exports.manualCourtScraper = functions.https.onRequest(async (req, res) => {
    console.log("Starting Manual Court Scraper via HTTPS...");
    try {
        const results = await scrapeCourtDates();
        res.status(200).send({
            status: "Completed",
            results: results
        });
    } catch (error) {
        res.status(500).send({
            status: "Error",
            message: error.message
        });
    }
});
