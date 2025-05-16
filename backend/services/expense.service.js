// services/expense.service.js
const ExpenseModel = require('../models/Expense');

const ExpenseService = {
  async createExpense(expenseData) {
    const { amount } = expenseData;
    
    // Validate amount
    if (amount <= 0) {
      throw new Error('Amount must be positive');
    }
    
    // Create expense
    const expense = await ExpenseModel.create(expenseData);
    return expense;
  },
  
  async getExpensesByFirebaseUid(firebaseUid) {
    const expenses = await ExpenseModel.find({ firebaseUid });
    return expenses;
  },
  
  async getExpenseById(expenseId) {
    const expense = await ExpenseModel.findById(expenseId);
    if (!expense) {
      throw new Error('Expense not found');
    }
    return expense;
  },
  
  async updateExpense(expenseId, firebaseUid, updateData) {
    // Check if expense exists and belongs to user
    const expense = await ExpenseModel.findById(expenseId);
    if (!expense) {
      throw new Error('Expense not found');
    }
    
    if (expense.firebaseUid !== firebaseUid) {
      throw new Error('Unauthorized: You do not own this expense');
    }
    
    // Update expense
    const updatedExpense = await ExpenseModel.findByIdAndUpdate(
      expenseId,
      updateData,
      { new: true }
    );
    
    return updatedExpense;
  },
  
  async deleteExpense(expenseId, firebaseUid) {
    // Check if expense exists and belongs to user
    const expense = await ExpenseModel.findById(expenseId);
    if (!expense) {
      throw new Error('Expense not found');
    }
    
    if (expense.firebaseUid !== firebaseUid) {
      throw new Error('Unauthorized: You do not own this expense');
    }
    
    // Delete expense
    await ExpenseModel.findByIdAndDelete(expenseId);
    return { message: 'Expense deleted successfully' };
  },
};

module.exports = ExpenseService;