// services/budget.service.js
const BudgetModel = require('../models/Budget');
const ExpenseModel = require('../models/Expense');

const BudgetService = {
  async createBudget(budgetData) {
    const { budget } = budgetData;
    
    // Validate budget amount
    if (budget <= 0) {
      throw new Error('Budget amount must be positive');
    }
    
    // Set initial spent to 0 if not provided
    if (!budgetData.spent) {
      budgetData.spent = 0;
    }
    
    // Create budget
    const newBudget = await BudgetModel.create(budgetData);
    return newBudget;
  },
  
  async getBudgetsByFirebaseUid(firebaseUid) {
    const budgets = await BudgetModel.find({ firebaseUid });
    return budgets;
  },
  
  async getBudgetById(budgetId) {
    const budget = await BudgetModel.findById(budgetId);
    if (!budget) {
      throw new Error('Budget not found');
    }
    return budget;
  },
  
  async updateBudget(budgetId, firebaseUid, updateData) {
    // Check if budget exists and belongs to user
    const budget = await BudgetModel.findById(budgetId);
    if (!budget) {
      throw new Error('Budget not found');
    }
    
    if (budget.firebaseUid !== firebaseUid) {
      throw new Error('Unauthorized: You do not own this budget');
    }
    
    // Validate budget amount if it's being updated
    if (updateData.budget && updateData.budget <= 0) {
      throw new Error('Budget amount must be positive');
    }
    
    // Update budget
    const updatedBudget = await BudgetModel.findByIdAndUpdate(
      budgetId,
      updateData,
      { new: true }
    );
    
    return updatedBudget;
  },
  
  async deleteBudget(budgetId, firebaseUid) {
    // Check if budget exists and belongs to user
    const budget = await BudgetModel.findById(budgetId);
    if (!budget) {
      throw new Error('Budget not found');
    }
    
    if (budget.firebaseUid !== firebaseUid) {
      throw new Error('Unauthorized: You do not own this budget');
    }
    
    // Delete budget
    await BudgetModel.findByIdAndDelete(budgetId);
    return { message: 'Budget deleted successfully' };
  },
  
  async updateBudgetSpent(firebaseUid, category, amount) {
    // Find the most recent budget for this category
    const budget = await BudgetModel.findOne({ 
      firebaseUid, 
      category 
    }).sort({ date: -1 });
    
    if (!budget) {
      return null; // No budget found for this category
    }
    
    // Update the spent amount
    budget.spent += amount;
    await budget.save();
    
    return budget;
  },
};

module.exports = BudgetService;