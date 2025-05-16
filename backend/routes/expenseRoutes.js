// routes/expenseRoutes.js
const express = require("express")
const router = express.Router()
const Expense = require("../models/Expense")
const Goal = require("../models/Goal")
const verifyFirebaseToken = require("../middleware/verifyFirebaseToken")
const updateBudgetSpent = require("../utils/updateBudgetSpent")
const { getDateRangeFromMonth } = require("../utils/dateUtils")

// Helper function to update goal progress
async function updateGoalProgress(goalId, userId, amountChange) {
  if (!goalId) return null

  try {
    // Find the goal
    const goal = await Goal.findOne({ _id: goalId, firebaseUid: userId })
    if (!goal) {
      console.log(`Goal ${goalId} not found for user ${userId}`)
      return null
    }

    // Calculate new progress by ADDING the amount change to the existing progress
    // This ensures we're accumulating progress rather than overwriting it
    let newProgress = (goal.progress || 0) + amountChange

    // Validate progress (never negative, never exceeds goal amount)
    newProgress = Math.max(0, newProgress) // Ensure not negative
    newProgress = Math.min(newProgress, goal.amount) // Ensure doesn't exceed goal amount

    console.log(`Updating goal ${goalId} progress: ${goal.progress} → ${newProgress} (change: ${amountChange})`)

    // Update the goal
    goal.progress = newProgress
    await goal.save()

    return goal
  } catch (err) {
    console.error(`Error updating goal progress: ${err.message}`)
    return null
  }
}

// Add expense
router.post("/", verifyFirebaseToken, async (req, res) => {
  const { amount, payee, category, frequency, description, dueDate, goalId } = req.body
  try {
    const expense = new Expense({
      firebaseUid: req.user.uid,
      amount,
      payee,
      category,
      frequency,
      description,
      dueDate: dueDate ? new Date(dueDate) : null,
      date: new Date(),
      active: true,
      goalId: goalId || null, // Include the goal ID if provided
    })
    await expense.save()

    // If this expense is linked to a goal, update the goal's progress
    if (goalId) {
      await updateGoalProgress(goalId, req.user.uid, amount)
    }

    // Recalculate the budget's spent field.
    await updateBudgetSpent(req.user.uid, category)

    res.status(201).json({ message: "Expense added successfully", expense })
  } catch (err) {
    console.error(`Error adding expense: ${err.message}`)
    res.status(500).json({ message: `Error adding expense: ${err.message}` })
  }
})

// Similarly update the PUT route to handle goalId
router.put("/:id", verifyFirebaseToken, async (req, res) => {
  const { id } = req.params
  const { amount, payee, category, frequency, description, dueDate, active, goalId } = req.body
  try {
    // Get the original expense to check if goalId or amount changed
    const originalExpense = await Expense.findById(id)
    if (!originalExpense || originalExpense.firebaseUid !== req.user.uid) {
      return res.status(404).json({ message: "Expense not found" })
    }

    // If the expense was previously linked to a goal, update that goal's progress
    if (originalExpense.goalId) {
      await updateGoalProgress(originalExpense.goalId, req.user.uid, -originalExpense.amount)
    }

    // Update the expense
    const updatedExpense = await Expense.findOneAndUpdate(
      { _id: id, firebaseUid: req.user.uid },
      {
        amount,
        payee,
        category,
        frequency,
        description,
        dueDate: dueDate ? new Date(dueDate) : null,
        active,
        goalId: goalId || null, // Include the goal ID if provided
      },
      { new: true },
    )

    // If the expense is now linked to a goal, update that goal's progress
    if (goalId) {
      await updateGoalProgress(goalId, req.user.uid, amount)
    }

    await updateBudgetSpent(req.user.uid, category)
    res.status(200).json({ message: "Expense updated successfully", updatedExpense })
  } catch (err) {
    res.status(500).json({ message: `Error updating expense: ${err.message}` })
  }
})

// Get all expenses for the authenticated user (optionally filter by month)
router.get("/", verifyFirebaseToken, async (req, res) => {
  try {
    const userUid = req.user.uid
    const { month, goalId } = req.query
    const dateRange = getDateRangeFromMonth(month)
    const query = { firebaseUid: userUid }

    if (dateRange) {
      query.date = { $gte: dateRange.startDate, $lt: dateRange.endDate }
    }

    // If goalId is provided, filter by it
    if (goalId) {
      query.goalId = goalId
    }

    const expenses = await Expense.find(query).sort({ date: -1 }) // Sort by date descending (newest first)
    res.status(200).json(expenses)
  } catch (err) {
    res.status(500).json({ message: `Error fetching expenses: ${err.message}` })
  }
})

// Delete an expense entry
router.delete("/:id", verifyFirebaseToken, async (req, res) => {
  const { id } = req.params
  try {
    const deletedExpense = await Expense.findOneAndDelete({ _id: id, firebaseUid: req.user.uid })
    if (!deletedExpense) {
      return res.status(404).json({ message: "Expense not found" })
    }

    // If the expense was linked to a goal, update that goal's progress
    if (deletedExpense.goalId) {
      await updateGoalProgress(deletedExpense.goalId, req.user.uid, -deletedExpense.amount)
    }

    await updateBudgetSpent(req.user.uid, deletedExpense.category)
    res.status(200).json({ message: "Expense deleted successfully" })
  } catch (err) {
    res.status(500).json({ message: `Error deleting expense: ${err.message}` })
  }
})

// Predict next month's expenses
const { SLR } = require("ml-regression")
const moment = require("moment")

router.get("/predict", verifyFirebaseToken, async (req, res) => {
  try {
    const userUid = req.user.uid
    const expenses = await Expense.find({ firebaseUid: userUid }).sort({ date: 1 })
    if (expenses.length < 1) {
      return res.status(400).json({
        message: "Not enough data to make predictions. Add more expenses to get predictions.",
      })
    }
    const data = expenses.map((exp) => ({
      month: moment(exp.date).startOf("month").valueOf(),
      amount: exp.amount,
      category: exp.category,
    }))
    const uniqueMonths = [...new Set(data.map((d) => d.month))]
    const aggregatedData = uniqueMonths.map((month) => {
      const total = data.filter((d) => d.month === month).reduce((sum, d) => sum + d.amount, 0)
      return { month, total }
    })
    const categoryTotals = data.reduce((acc, curr) => {
      acc[curr.category] = (acc[curr.category] || 0) + curr.amount
      return acc
    }, {})
    aggregatedData.sort((a, b) => a.month - b.month)
    if (aggregatedData.length > 1) {
      const X = aggregatedData.map((d, index) => index + 1)
      const Y = aggregatedData.map((d) => d.total)
      const regression = new SLR(X, Y)
      const nextMonth = X[X.length - 1] + 1
      const prediction = regression.predict(nextMonth)
      res.status(200).json({
        message: "Prediction successful",
        prediction: prediction,
        categoryPredictions: categoryTotals,
      })
    } else {
      const lastMonthExpense = aggregatedData[aggregatedData.length - 1].total
      res.status(200).json({
        message: "Prediction successful",
        prediction: lastMonthExpense,
        categoryPredictions: categoryTotals,
      })
    }
  } catch (err) {
    res.status(500).json({ message: `Error predicting expenses: ${err.message}` })
  }
})

module.exports = router

