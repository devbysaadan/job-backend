// Har step par log lagaya hai taaki pata chale code kahan atak raha hai
console.log("Step 1: Code file run hona shuru hui...");

require('dotenv').config();
const express = require('express');
const cors = require('cors');
const axios = require('axios');
const { GoogleGenerativeAI } = require('@google/generative-ai');

console.log("Step 2: Saare packages successfully import ho gaye...");

// Yeh dono function kisi bhi silent crash ko pakad kar terminal mein print kar denge
process.on('uncaughtException', (err) => {
    console.error("🚨 CRITICAL ERROR (Uncaught Exception):", err);
});
process.on('unhandledRejection', (reason, promise) => {
    console.error("🚨 CRITICAL ERROR (Unhandled Promise):", reason);
});

const app = express();
app.use(cors());
app.use(express.json());

console.log("Step 3: Express setup ho gaya...");

// Agar Gemini bina key ke crash kar raha hoga, toh yeh block usko pakad lega
let genAI;
try {
    const apiKey = process.env.GEMINI_API_KEY || "test_key";
    genAI = new GoogleGenerativeAI(apiKey);
    console.log("Step 4: Gemini SDK initialize ho gaya...");
} catch (error) {
    console.error("🚨 GEMINI INITIALIZATION ERROR:", error);
}

app.post('/search-jobs', async (req, res) => {
    try {
        const { query, customLinks } = req.body;
        const searchQuery = query || "Latest worldwide remote contract Flutter developer jobs";

        let tavilyPayload = {
            api_key: process.env.TAVILY_API_KEY,
            query: searchQuery,
            search_depth: "advanced",
            include_raw_content: true,
            max_results: 15
        };

        if (customLinks && customLinks.length > 0) {
            tavilyPayload.include_domains = customLinks;
        }

        const tavilyResponse = await axios.post('https://api.tavily.com/search', tavilyPayload);
        const rawData = JSON.stringify(tavilyResponse.data.results);

        const model = genAI.getGenerativeModel({ model: "gemini-2.5-flash" });
        const prompt = `
        You are an expert tech recruiter. I am giving you raw web search data.
        Your task is to find recently posted jobs based on this search.
        
        Rules:
        1. Extract the exact Job Title, Company Name, Salary/Rate (if mentioned, otherwise "Not Disclosed"), Date Posted (if available), and Application Link.
        2. Output ONLY a valid JSON array. Do not write any markdown formatting like \`\`\`json. Just the raw JSON array.
        
        Raw Data to process: ${rawData}
        `;

        const result = await model.generateContent(prompt);
        let aiResponse = result.response.text();
        aiResponse = aiResponse.replace(/```json/g, "").replace(/```/g, "").trim();

        res.json({ success: true, data: JSON.parse(aiResponse) });

    } catch (error) {
        console.error("API ERROR:", error);
        res.status(500).json({ success: false, error: error.message });
    }
});

const PORT = process.env.PORT || 3000;

// Render ke liye '0.0.0.0' host add karna best practice hai
app.listen(PORT, '0.0.0.0', () => {
    console.log(`Step 5: SUCCESS! Server bind ho gaya port ${PORT} par 🚀`);
});