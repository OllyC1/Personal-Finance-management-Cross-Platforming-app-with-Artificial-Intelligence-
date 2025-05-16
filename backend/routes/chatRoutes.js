// routes/chatRoutes.js

require('dotenv').config();

const express = require('express');
const router = express.Router();
const verifyFirebaseToken = require('../middleware/verifyFirebaseToken');
const axios = require('axios');

// Require models to fetch user data.
const User = require('../models/User');
const Income = require('../models/Income');
const Expense = require('../models/Expense');
const Goal = require('../models/Goal');
const Budget = require('../models/Budget');

// DeepSeek API settings
// Use the provided DeepSeek base URL. You can also use https://api.deepseek.com/v1
const DEEPSEEK_BASE_URL = process.env.DEEPSEEK_BASE_URL || "https://api.deepseek.com";
const DEEPSEEK_API_KEY = process.env.DEEPSEEK_API_KEY;

console.log("DEEPSEEK_API_KEY:", DEEPSEEK_API_KEY ? "Set" : "Not set");
console.log("DEEPSEEK_BASE_URL:", DEEPSEEK_BASE_URL);

// Helper function to get user's financial data
async function getUserFinancialData(userUid) {
  const now = new Date();
  const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);
  const monthEnd = new Date(now.getFullYear(), now.getMonth() + 1, 0);

  const [user, incomes, expenses, goals, budgets] = await Promise.all([
    User.findOne({ firebaseUid: userUid }),
    Income.find({ firebaseUid: userUid, date: { $gte: monthStart, $lt: monthEnd } }),
    Expense.find({ firebaseUid: userUid, date: { $gte: monthStart, $lt: monthEnd } }),
    Goal.find({ firebaseUid: userUid }),
    Budget.find({ firebaseUid: userUid })
  ]);

  const totalIncome = incomes.reduce((sum, inc) => sum + (inc.amount || 0), 0);
  const totalExpenses = expenses.reduce((sum, exp) => sum + (exp.amount || 0), 0);

  const { totalSavings, totalDebt } = goals.reduce((acc, goal) => {
    if (goal.type && goal.type.toLowerCase() === 'savings') {
      acc.totalSavings += goal.progress || 0;
    } else if (goal.type && goal.type.toLowerCase() === 'debt') {
      acc.totalDebt += goal.progress || 0;
    }
    return acc;
  }, { totalSavings: 0, totalDebt: 0 });

  const budgetSummary = budgets.length > 0
    ? budgets
        .map(budget => `${budget.category}: £${(budget.budget - (budget.spent || 0)).toFixed(2)} remaining`)
        .join('; ')
    : "No budget data available.";

  return {
    username: user ? user.username : "there",
    totalIncome,
    totalExpenses,
    totalSavings,
    totalDebt,
    budgetSummary
  };
}

router.post('/', verifyFirebaseToken, async (req, res) => {
  try {
    const { message } = req.body;
    const userUid = req.user.uid;

    const {
      username,
      totalIncome,
      totalExpenses,
      totalSavings,
      totalDebt,
      budgetSummary
    } = await getUserFinancialData(userUid);

    // Build a concise financial summary (for context only).
    const financialSummary = `
User Financial Data:
- Monthly Income: £${totalIncome.toFixed(2)}
- Monthly Expenses: £${totalExpenses.toFixed(2)}
- Budget: ${budgetSummary}
- Savings: £${totalSavings.toFixed(2)}
- Debt: £${totalDebt.toFixed(2)}
    `;

    // Construct the system message with context and instructions.
    const systemMessage = `
You are Olly, a friendly, professional financial advisor. Address the user as ${username}.
The following information is provided for context only. Do not repeat it in your answer.
${financialSummary}
Instructions:
1. If the user is greeting you, respond with a warm welcome and ask how you can help with their finances today.
2. Provide clear, actionable financial advice based on the user's query and their financial data.
3. If the user asks multiple questions, address each one separately.
4. Encourage the user to provide more information if needed for better advice.
5. Always maintain a professional yet friendly tone.
    `;

    // Construct the messages array as required by the OpenAI-compatible API.
    const messages = [
      {
        role: "system",
        content: systemMessage.trim()
      },
      {
        role: "user",
        content: message
      }
    ];

    // Prepare the payload for DeepSeek API.
    const payload = {
      model: "deepseek-chat", // or change to "deepseek-reasoner" if needed.
      messages: messages,
      stream: false,
      max_tokens: 1000,
      temperature: 0.5,
      top_p: 0.95
    };

    // DeepSeek Chat Completions endpoint.
    const endpoint = `${DEEPSEEK_BASE_URL}/chat/completions`;

    const headers = {
      "Content-Type": "application/json",
      "Authorization": `Bearer ${DEEPSEEK_API_KEY}`
    };

    // Send the request.
    const response = await axios.post(endpoint, payload, { headers });

    // According to the OpenAI format, the generated reply is in response.data.choices[0].message.content
    const reply = response.data.choices[0]?.message?.content;
    if (!reply) {
      return res.status(500).json({ message: "No generated text found in the response." });
    }

    res.status(200).json({ reply: reply.trim() });
  } catch (err) {
    console.error("Error processing chat:", err);
    res.status(500).json({
      message: `Error processing chat: ${err.message}`,
      details: err.toString(),
      stack: err.stack
    });
  }
});

module.exports = router;
