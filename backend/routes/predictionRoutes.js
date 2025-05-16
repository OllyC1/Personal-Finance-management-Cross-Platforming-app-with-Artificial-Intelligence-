// routes/predictionRoutes.js
const express = require('express');
const router = express.Router();
const Expense = require('../models/Expense');
const Income = require('../models/Income');
const Goal = require('../models/Goal');
const verifyFirebaseToken = require('../middleware/verifyFirebaseToken');
const { SLR } = require('ml-regression');
const moment = require('moment');

router.get('/', verifyFirebaseToken, async (req, res) => {
  try {
    const userUid = req.user.uid;

    // Fetch expenses and sort by date
    const expenses = await Expense.find({ firebaseUid: userUid }).sort({ date: 1 });
    // Fetch incomes and sort by date
    const incomes = await Income.find({ firebaseUid: userUid }).sort({ date: 1 });
    // Fetch goals (for savings and debt)
    const goals = await Goal.find({ firebaseUid: userUid });
    
    // Predict expenses using linear regression if enough data
    let expensePrediction = 0;
    let expenseCategoryPredictions = {};
    
    // Get the last month's expense amount for fallback
    const lastMonthExpense = expenses.length > 0 ? expenses[expenses.length - 1].amount : 0;
    
    if (expenses.length >= 2) {
      const X = expenses.map((_, i) => i + 1);
      const Y = expenses.map(exp => exp.amount);
      const regression = new SLR(X, Y);
      
      // Get the prediction from regression
      const predictedValue = regression.predict(X.length + 1);
      
      // If prediction is negative, use the last month's expense instead
      expensePrediction = predictedValue < 0 ? lastMonthExpense : predictedValue;
      
      // Group expense amounts by category for a simple "breakdown"
      expenses.forEach(exp => {
        if (!expenseCategoryPredictions[exp.category]) {
          expenseCategoryPredictions[exp.category] = 0;
        }
        expenseCategoryPredictions[exp.category] += exp.amount;
      });
    } else if(expenses.length > 0) {
      expensePrediction = lastMonthExpense;
    }

    // Predict income similarly
    let incomePrediction = 0;
    if (incomes.length >= 2) {
      const X = incomes.map((_, i) => i + 1);
      const Y = incomes.map(inc => inc.amount);
      const regression = new SLR(X, Y);
      incomePrediction = regression.predict(X.length + 1);
      // Ensure income prediction is not negative
      incomePrediction = Math.max(0, incomePrediction);
    } else if (incomes.length > 0) {
      incomePrediction = incomes[incomes.length - 1].amount;
    }
    
    // For goals (Savings and Debt) we simply sum the current progress as prediction
    let savingsPrediction = 0;
    let debtPrediction = 0;
    goals.forEach(goal => {
      if ((goal.type || '').toLowerCase() === 'savings') {
        savingsPrediction += goal.progress;
      } else if ((goal.type || '').toLowerCase() === 'debt') {
        debtPrediction += goal.progress;
      }
    });

    res.status(200).json({
      message: 'Prediction successful',
      predictions: {
        expense: expensePrediction,
        income: incomePrediction,
        savings: savingsPrediction,
        debt: debtPrediction,
      },
      expenseCategoryPredictions: expenseCategoryPredictions
    });
  } catch (err) {
    res.status(500).json({ message: `Error predicting: ${err.message}` });
  }
});

module.exports = router;