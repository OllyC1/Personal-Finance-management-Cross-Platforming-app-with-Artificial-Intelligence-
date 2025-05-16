// routes/budgetRoutes.js
const express = require("express")
const router = express.Router()
const Budget = require("../models/Budget")
const verifyFirebaseToken = require("../middleware/verifyFirebaseToken")
const { getDateRangeFromMonth } = require("../utils/dateUtils")
const Expense = require("../models/Expense") // Ensure Expense model is imported

// Add or update a budget
router.post("/", verifyFirebaseToken, async (req, res) => {
  const { category, budget, date, rollover } = req.body
  try {
    // Get current month's date range
    const now = new Date()
    const currentMonth = now.toISOString().substring(0, 7) // YYYY-MM format
    const dateRange = getDateRangeFromMonth(currentMonth)

    // First check if a budget for this category already exists in the current month
    const existingBudget = await Budget.findOne({
      firebaseUid: req.user.uid,
      category: category,
      date: { $gte: dateRange.startDate, $lt: dateRange.endDate },
    })

    // Calculate total spent for this category in the current month
    // This will be used for both new and existing budgets
    const expenses = await Expense.find({
      firebaseUid: req.user.uid,
      category: category,
      date: { $gte: dateRange.startDate, $lt: dateRange.endDate },
      active: true, // Only count active expenses
    })

    const totalSpent = expenses.reduce((sum, expense) => sum + expense.amount, 0)
    console.log(`Total spent for ${category} in current month: ${totalSpent}`)

    if (existingBudget) {
      // Update existing budget
      existingBudget.budget = budget
      existingBudget.rollover = rollover === true
      existingBudget.spent = totalSpent // Update spent amount
      await existingBudget.save()

      res.status(200).json({
        message: "Budget updated successfully",
        budgetEntry: existingBudget,
      })
    } else {
      // Create new budget
      const newBudget = new Budget({
        firebaseUid: req.user.uid,
        category,
        budget,
        rollover: rollover === true,
        date: date ? new Date(date) : new Date(),
        spent: totalSpent, // Set initial spent amount based on existing expenses
        rolloverAmount: 0, // Initialize rollover amount to 0
      })

      await newBudget.save()

      res.status(201).json({
        message: "Budget added successfully",
        budgetEntry: newBudget,
      })
    }
  } catch (err) {
    console.error("Error adding/updating budget:", err)
    res.status(500).json({ message: `Error adding/updating budget: ${err.message}` })
  }
})

// Get all budgets for the user (optionally filter by month)
router.get("/", verifyFirebaseToken, async (req, res) => {
  console.log("Fetching budgets for user:", req.user.uid)
  try {
    const { month } = req.query

    // Ensure dateRange is properly initialized
    let dateRange
    try {
      dateRange = getDateRangeFromMonth(month)
      console.log(`Date range for ${month || "current month"}: ${dateRange.startDate} to ${dateRange.endDate}`)
    } catch (error) {
      console.error(`Error getting date range: ${error.message}`)
      // Use current month as fallback
      const now = new Date()
      const currentMonth = now.toISOString().substring(0, 7)
      dateRange = getDateRangeFromMonth(currentMonth)
    }

    const query = { firebaseUid: req.user.uid }
    if (dateRange && dateRange.startDate && dateRange.endDate) {
      query.date = { $gte: dateRange.startDate, $lt: dateRange.endDate }
    }

    const budgets = await Budget.find(query)

    // Process monthly rollovers if we're at the start of a new month
    const now = new Date()
    const isStartOfMonth = now.getDate() <= 5 // Consider first 5 days of month as "start"

    if (isStartOfMonth) {
      // Get previous month's date range
      const prevMonth = new Date(now)
      prevMonth.setMonth(prevMonth.getMonth() - 1)
      const prevMonthStr = prevMonth.toISOString().substring(0, 7) // YYYY-MM format
      const prevDateRange = getDateRangeFromMonth(prevMonthStr)

      // Find budgets from previous month that have rollover enabled
      const prevBudgets = await Budget.find({
        firebaseUid: req.user.uid,
        rollover: true,
        date: { $gte: prevDateRange.startDate, $lt: prevDateRange.endDate },
      })

      // Process each budget with rollover
      for (const prevBudget of prevBudgets) {
        // Find corresponding budget for current month
        const currentBudget = budgets.find(
          (b) => b.category === prevBudget.category && b.date >= dateRange.startDate && b.date < dateRange.endDate,
        )

        if (currentBudget) {
          // Calculate rollover amount (unspent budget from previous month)
          const unspentAmount = Math.max(0, prevBudget.budget - prevBudget.spent)

          if (unspentAmount > 0) {
            // Add rollover amount to current month's budget
            currentBudget.rolloverAmount = unspentAmount
            await currentBudget.save()
            console.log(`Applied rollover of ${unspentAmount} to ${currentBudget.category} budget`)
          }
        }
      }

      // Refresh budgets after processing rollovers
      const updatedBudgets = await Budget.find(query)
      res.status(200).json(updatedBudgets)
    } else {
      res.status(200).json(budgets)
    }
  } catch (err) {
    console.error("Error fetching budgets:", err)
    res.status(500).json({ message: `Error fetching budgets: ${err.message}` })
  }
})

// Update an existing budget
router.put("/:id", verifyFirebaseToken, async (req, res) => {
  const { id } = req.params
  const { category, budget, date, rollover } = req.body
  try {
    const updatedBudget = await Budget.findOneAndUpdate(
      { _id: id, firebaseUid: req.user.uid },
      {
        category,
        budget,
        rollover: rollover === true,
        date: date ? new Date(date) : new Date(),
      },
      { new: true },
    )
    if (!updatedBudget) {
      return res.status(404).json({ message: "Budget not found" })
    }
    res.status(200).json({ message: "Budget updated successfully", budget: updatedBudget })
  } catch (err) {
    res.status(500).json({ message: `Error updating budget: ${err.message}` })
  }
})

// Delete a budget
router.delete("/:id", verifyFirebaseToken, async (req, res) => {
  const { id } = req.params
  try {
    const deletedBudget = await Budget.findOneAndDelete({ _id: id, firebaseUid: req.user.uid })
    if (!deletedBudget) {
      return res.status(404).json({ message: "Budget not found" })
    }
    res.status(200).json({ message: "Budget deleted successfully" })
  } catch (err) {
    res.status(500).json({ message: `Error deleting budget: ${err.message}` })
  }
})

module.exports = router

