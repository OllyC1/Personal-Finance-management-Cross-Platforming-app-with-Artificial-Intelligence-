// utils/updateBudgetSpent.js
const Budget = require("../models/Budget")
const Expense = require("../models/Expense")
const { getDateRangeFromMonth } = require("./dateUtils")

/**
 * Updates the spent field of a budget based on expenses in the current month
 * @param {string} userId - The user's Firebase UID
 * @param {string} category - The expense category
 */
async function updateBudgetSpent(userId, category) {
  try {
    // Get current month's date range
    const now = new Date()
    const currentMonth = now.toISOString().substring(0, 7) // YYYY-MM format
    const dateRange = getDateRangeFromMonth(currentMonth)

    // Find the budget for this category in the current month
    const budget = await Budget.findOne({
      firebaseUid: userId,
      category: category,
      date: { $gte: dateRange.startDate, $lt: dateRange.endDate },
    })

    if (!budget) {
      console.log(`No budget found for category ${category} in current month`)
      return
    }

    // Calculate total spent for this category in the current month
    const expenses = await Expense.find({
      firebaseUid: userId,
      category: category,
      date: { $gte: dateRange.startDate, $lt: dateRange.endDate },
      active: true, // Only count active expenses
    })

    const totalSpent = expenses.reduce((sum, expense) => sum + expense.amount, 0)

    // Update the budget's spent field
    budget.spent = totalSpent
    await budget.save()

    console.log(`Updated spent amount for ${category} budget: ${totalSpent}`)
    return budget
  } catch (err) {
    console.error(`Error updating budget spent: ${err.message}`)
    return null
  }
}

module.exports = updateBudgetSpent

