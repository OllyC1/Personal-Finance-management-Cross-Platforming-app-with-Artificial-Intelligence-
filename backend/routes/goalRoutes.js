const express = require("express")
const router = express.Router()
const Goal = require("../models/Goal")
const Expense = require("../models/Expense")
const verifyFirebaseToken = require("../middleware/verifyFirebaseToken")
const { getDateRangeFromMonth } = require("../utils/dateUtils")

// Utility function to validate and correct goal progress
async function validateAndCorrectGoalProgress(goalId, userId) {
  try {
    // Find the goal
    const goal = await Goal.findOne({ _id: goalId, firebaseUid: userId })
    if (!goal) {
      console.log(`Goal ${goalId} not found for user ${userId}`)
      return null
    }

    // Find all expenses linked to this goal
    const linkedExpenses = await Expense.find({
      goalId: goalId,
      firebaseUid: userId,
      active: true, // Only consider active expenses
    })

    // Calculate the sum of linked expenses
    const expensesTotal = linkedExpenses.reduce((sum, expense) => sum + expense.amount, 0)

    // Get the initial progress value (saved so far) from the goal's creation
    // We need to check if this is a new goal or if it has linked expenses
    let initialProgress = goal.initialProgress || 0

    // If initialProgress is not set, we'll set it now based on the current progress
    // This is for backward compatibility with existing goals
    if (initialProgress === 0 && goal.progress > 0 && expensesTotal === 0) {
      initialProgress = goal.progress
      // Save the initialProgress for future reference
      goal.initialProgress = initialProgress
      await goal.save()
      console.log(`Set initial progress for goal ${goalId} to ${initialProgress}`)
    }

    // The correct progress should be the initial progress plus the sum of linked expenses
    const calculatedProgress = initialProgress + expensesTotal

    // Validate progress (never negative, never exceeds goal amount)
    let validatedProgress = Math.max(0, calculatedProgress) // Ensure not negative
    validatedProgress = Math.min(validatedProgress, goal.amount) // Ensure doesn't exceed goal amount

    // If the progress in the database differs from the calculated progress, update it
    if (goal.progress !== validatedProgress) {
      console.log(`Correcting goal ${goalId} progress: ${goal.progress} → ${validatedProgress}`)
      goal.progress = validatedProgress
      await goal.save()
    }

    return goal
  } catch (err) {
    console.error(`Error validating goal progress: ${err.message}`)
    return null
  }
}

// Endpoint to manually reconcile all goals for a user
router.post("/reconcile", verifyFirebaseToken, async (req, res) => {
  try {
    const userUid = req.user.uid

    // Get all goals for the user
    const goals = await Goal.find({ firebaseUid: userUid })

    // Process each goal
    const results = await Promise.all(
      goals.map(async (goal) => {
        const updatedGoal = await validateAndCorrectGoalProgress(goal._id, userUid)
        return {
          goalId: goal._id,
          name: goal.name,
          type: goal.type,
          corrected: updatedGoal ? updatedGoal.progress !== goal.progress : false,
          oldProgress: goal.progress,
          newProgress: updatedGoal ? updatedGoal.progress : goal.progress,
        }
      }),
    )

    // Count how many goals were corrected
    const correctedCount = results.filter((r) => r.corrected).length

    res.status(200).json({
      message: `Reconciliation complete. ${correctedCount} goals were corrected.`,
      results,
    })
  } catch (err) {
    console.error(`Error reconciling goals: ${err.message}`)
    res.status(500).json({ message: `Error reconciling goals: ${err.message}` })
  }
})

// GET /goals
router.get("/", verifyFirebaseToken, async (req, res) => {
  try {
    const { month } = req.query
    const userUid = req.user.uid
    const dateRange = getDateRangeFromMonth(month)
    const query = { firebaseUid: userUid }
    if (dateRange) {
      query.date = { $gte: dateRange.startDate, $lt: dateRange.endDate }
    }
    const goals = await Goal.find(query)
    res.status(200).json(goals)
  } catch (err) {
    res.status(500).json({ message: `Error fetching goals: ${err.message}` })
  }
})

// IMPORTANT: Move the /details endpoint BEFORE the /:id route
// Modify the /details endpoint to ensure it's calculating progress correctly
router.get("/details", verifyFirebaseToken, async (req, res) => {
  try {
    const userUid = req.user.uid

    // Add a timestamp to prevent caching
    const timestamp = Date.now()
    console.log(`Fetching goal details at ${timestamp}`)

    // Get all goals for the user
    const goals = await Goal.find({ firebaseUid: userUid })

    // For each goal, ensure we have the latest progress data
    const goalDetails = await Promise.all(
      goals.map(async (goal) => {
        const duration = goal.duration || 1
        const monthlyTarget = goal.amount / duration

        // Validate and correct the goal progress if needed
        await validateAndCorrectGoalProgress(goal._id, userUid)

        // Get the updated goal after validation
        const updatedGoal = await Goal.findById(goal._id)
        const progress = updatedGoal.progress || 0
        const remaining = updatedGoal.amount > progress ? updatedGoal.amount - progress : 0

        console.log(`Goal ${goal._id}: ${goal.name}, Progress: ${progress}, Amount: ${goal.amount}`)

        return {
          _id: goal._id,
          name: goal.name,
          type: goal.type,
          amount: goal.amount,
          duration: duration,
          monthlyTarget: monthlyTarget,
          progress: progress,
          remaining: remaining,
          initialProgress: updatedGoal.initialProgress || 0, // Include initialProgress in the response
        }
      }),
    )

    res.status(200).json(goalDetails)
  } catch (err) {
    console.error(`Error fetching goal details: ${err.message}`)
    res.status(500).json({ message: `Error fetching goal details: ${err.message}` })
  }
})

// Route to get a specific goal by ID - MOVED AFTER /details
router.get("/:id", async (req, res) => {
  try {
    const goal = await Goal.findById(req.params.id)
    if (!goal) {
      return res.status(404).json({ message: "Goal not found" })
    }
    res.json(goal)
  } catch (err) {
    res.status(500).json({ message: err.message })
  }
})

// POST /goals
router.post("/", verifyFirebaseToken, async (req, res) => {
  const { name, amount, progress, type, date, duration } = req.body
  try {
    // Validate progress (never negative, never exceeds goal amount)
    let validatedProgress = Math.max(0, progress || 0) // Ensure not negative
    validatedProgress = Math.min(validatedProgress, amount) // Ensure doesn't exceed goal amount

    const newGoal = await Goal.create({
      name,
      amount,
      progress: validatedProgress, // Use validated progress
      initialProgress: validatedProgress, // Store the initial progress separately
      type,
      duration,
      date: date ? new Date(date) : new Date(),
      firebaseUid: req.user.uid,
    })
    res.status(201).json({ message: "Goal added successfully", goal: newGoal })
  } catch (err) {
    res.status(500).json({ message: `Error adding goal: ${err.message}` })
  }
})

// PUT /goals/:id
router.put("/:id", verifyFirebaseToken, async (req, res) => {
  const { id } = req.params
  const { name, amount, progress, type, duration } = req.body
  try {
    // Get the original goal to check if we need to update initialProgress
    const originalGoal = await Goal.findById(id)
    if (!originalGoal || originalGoal.firebaseUid !== req.user.uid) {
      return res.status(404).json({ message: "Goal not found" })
    }

    // Validate progress (never negative, never exceeds goal amount)
    let validatedProgress = Math.max(0, progress || 0) // Ensure not negative
    validatedProgress = Math.min(validatedProgress, amount) // Ensure doesn't exceed goal amount

    // Find linked expenses to calculate how much of the progress comes from expenses
    const linkedExpenses = await Expense.find({
      goalId: id,
      firebaseUid: req.user.uid,
      active: true,
    })
    const expensesTotal = linkedExpenses.reduce((sum, expense) => sum + expense.amount, 0)

    // Calculate new initialProgress based on the difference between the requested progress and expenses
    const newInitialProgress = Math.max(0, validatedProgress - expensesTotal)

    const updatedGoal = await Goal.findOneAndUpdate(
      { _id: id, firebaseUid: req.user.uid },
      {
        name,
        amount,
        progress: validatedProgress, // Use validated progress
        initialProgress: newInitialProgress, // Update initialProgress
        type,
        duration,
      },
      { new: true },
    )
    if (!updatedGoal) {
      return res.status(404).json({ message: "Goal not found" })
    }
    res.status(200).json({ message: "Goal updated successfully", goal: updatedGoal })
  } catch (err) {
    res.status(500).json({ message: `Error updating goal: ${err.message}` })
  }
})

// DELETE /goals/:id
router.delete("/:id", verifyFirebaseToken, async (req, res) => {
  const { id } = req.params
  try {
    // First, find the goal to be deleted
    const goalToDelete = await Goal.findOne({ _id: id, firebaseUid: req.user.uid })
    if (!goalToDelete) {
      return res.status(404).json({ message: "Goal not found" })
    }

    // Find all expenses linked to this goal
    const linkedExpenses = await Expense.find({ goalId: id, firebaseUid: req.user.uid })

    // If there are linked expenses, update them to remove the goal link
    if (linkedExpenses.length > 0) {
      await Expense.updateMany({ goalId: id, firebaseUid: req.user.uid }, { $set: { goalId: null } })
    }

    // Now delete the goal
    const deletedGoal = await Goal.findOneAndDelete({ _id: id, firebaseUid: req.user.uid })

    res.status(200).json({
      message: "Goal deleted successfully",
      unlinkedExpenses: linkedExpenses.length,
    })
  } catch (err) {
    res.status(500).json({ message: `Error deleting goal: ${err.message}` })
  }
})

// Add a new endpoint to get expenses linked to a specific goal
router.get("/:id/expenses", verifyFirebaseToken, async (req, res) => {
  const { id } = req.params
  try {
    // First check if the goal exists and belongs to the user
    const goal = await Goal.findOne({ _id: id, firebaseUid: req.user.uid })
    if (!goal) {
      return res.status(404).json({ message: "Goal not found" })
    }

    // Find all expenses linked to this goal
    const linkedExpenses = await Expense.find({
      goalId: id,
      firebaseUid: req.user.uid,
    }).sort({ date: -1 }) // Sort by date descending (newest first)

    res.status(200).json(linkedExpenses)
  } catch (err) {
    res.status(500).json({ message: `Error fetching linked expenses: ${err.message}` })
  }
})

module.exports = router

