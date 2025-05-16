// routes/alertRoutes.js
const express = require('express');
const router = express.Router();
const Budget = require('../models/Budget');
const Expense = require('../models/Expense');
const verifyFirebaseToken = require('../middleware/verifyFirebaseToken');

// GET /alerts
router.get('/', verifyFirebaseToken, async (req, res) => {
  try {
    const userUid = req.user.uid;

    // ============================
    // 1) Budget Alerts (dynamic)
    // ============================
    // For each Budget, sum actual expenses, compute remaining, 
    // check if (remaining <= 20% of budget).
    const budgets = await Budget.find({ firebaseUid: userUid });
    const budgetAlerts = [];

    for (const budgetDoc of budgets) {
      const { category, budget: budgetAmount } = budgetDoc;

      if (budgetAmount > 0) {
        // Sum all expenses matching this category
        const expenseAgg = await Expense.aggregate([
          { $match: { firebaseUid: userUid, category } },
          { $group: { _id: null, totalSpent: { $sum: '$amount' } } },
        ]);

        const spent = expenseAgg.length > 0 ? expenseAgg[0].totalSpent : 0;
        const remaining = budgetAmount - spent;

        if (remaining <= 0.2 * budgetAmount) {
          budgetAlerts.push({
            category: category,
            message: `Budget for "${category}" is running low: £${remaining.toFixed(2)} remaining.`,
          });
        }
      }
    }

    // ============================
    // 2) Upcoming Expenses (7 days)
    // ============================
    // If the user sets a future dueDate in Expense, 
    // we consider it "unpaid" or "bill-like" if it's within 7 days.
    const now = new Date();
    const in7Days = new Date();
    in7Days.setDate(in7Days.getDate() + 7);

    // Find all expenses where `dueDate` is within [now, now+7 days]
    const upcomingExpenses = await Expense.find({
      firebaseUid: userUid,
      dueDate: { $gte: now, $lte: in7Days },
    });

    const expenseAlerts = upcomingExpenses.map((expense) => ({
      category: 'Upcoming Expense',
      message: `You have an expense of £${expense.amount.toFixed(2)} for "${expense.category}" due on ${new Date(expense.dueDate).toDateString()}.`,
    }));

    // Combine all alerts
    const alerts = [...budgetAlerts, ...expenseAlerts];

    if (alerts.length > 0) {
      res.status(200).json({ alerts });
    } else {
      res.status(200).json({ alerts: [], message: 'No alerts found.' });
    }
  } catch (err) {
    console.error('Error fetching alerts:', err);
    res.status(500).json({ message: `Error fetching alerts: ${err.message}` });
  }
});

module.exports = router;
