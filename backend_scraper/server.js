const express = require('express');
const { exec } = require('child_process');
const path = require('path');
const dotenv = require('dotenv');
const cron = require('node-cron');

dotenv.config();

const app = express();
app.use(express.json());
const PORT = process.env.PORT || 3000;

// Helper function to execute python scraper
function executePythonScraper(res = null) {
    console.log("Executing Python Scraper script...");
    const pythonScriptPath = path.join(__dirname, 'scraper.py');

    // Command to execute scraper.py
    exec(`python "${pythonScriptPath}"`, (error, stdout, stderr) => {
        if (error) {
            console.error(`Scraper Execution Error: ${error.message}`);
            if (res) {
                return res.status(500).json({
                    success: false,
                    message: "Scraper execution failed",
                    error: error.message
                });
            }
            return;
        }

        console.log(`Scraper Output:\n${stdout}`);
        if (res) {
            return res.status(200).json({
                success: true,
                message: "Instant scraping completed and Firestore updated successfully!"
            });
        }
    });
}

// 1. Root Test Route
app.get('/', (req, res) => {
    res.send("Smart Legal Assistant Scraper Server is Running Live!");
});

// 2. Instant Scraper Trigger Endpoint (Called by Mobile App / Flutter)
app.post('/api/trigger-scrape', (req, res) => {
    console.log("Instant Scrape Request Received from Mobile App!");
    executePythonScraper(res);
});

// 3. Alternative GET Route for quick browser testing
app.get('/run-scraper', (req, res) => {
    executePythonScraper(res);
});

// 4. Scheduled Task: Daily at 1:00 AM Pakistan Time (Asia/Karachi)
cron.schedule('0 1 * * *', () => {
    console.log("Running scheduled daily scraper at 1:00 AM PKT...");
    executePythonScraper();
}, {
    scheduled: true,
    timezone: "Asia/Karachi"
});

app.listen(PORT, () => {
    console.log(`Server is running on port ${PORT}`);
});