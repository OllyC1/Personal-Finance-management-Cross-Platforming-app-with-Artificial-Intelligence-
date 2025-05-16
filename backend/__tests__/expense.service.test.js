// __tests__/expense.service.test.js

// Mock dependencies
jest.mock('../models/Expense', () => ({
    find: jest.fn(),
    findById: jest.fn(),
    create: jest.fn(),
    findByIdAndUpdate: jest.fn(),
    findByIdAndDelete: jest.fn(),
  }));
  
  // Import the service (adjust the path as needed)
  const ExpenseService = require('../services/expense.service');
  
  describe('Expense Service', () => {
    beforeEach(() => {
      jest.clearAllMocks();
    });
  
    describe('createExpense', () => {
      it('should create a new expense successfully', async () => {
        // Mock dependencies
        const mockExpense = {
          _id: 'expense123',
          firebaseUid: 'firebase123',
          amount: 100,
          payee: 'Grocery Store',
          category: 'Food',
          frequency: 'Just once',
          date: new Date(),
        };
        
        const ExpenseModel = require('../models/Expense');
        ExpenseModel.create.mockResolvedValue(mockExpense);
        
        // Call the function
        const result = await ExpenseService.createExpense({
          firebaseUid: 'firebase123',
          amount: 100,
          payee: 'Grocery Store',
          category: 'Food',
          frequency: 'Just once',
          date: new Date(),
        });
        
        // Assertions
        expect(ExpenseModel.create).toHaveBeenCalledWith({
          firebaseUid: 'firebase123',
          amount: 100,
          payee: 'Grocery Store',
          category: 'Food',
          frequency: 'Just once',
          date: expect.any(Date),
        });
        expect(result).toEqual(mockExpense);
      });
  
      it('should throw an error if amount is negative', async () => {
        // Call the function and expect it to throw
        await expect(ExpenseService.createExpense({
          firebaseUid: 'firebase123',
          amount: -100,
          payee: 'Grocery Store',
          category: 'Food',
          frequency: 'Just once',
          date: new Date(),
        })).rejects.toThrow('Amount must be positive');
        
        // Assertions
        const ExpenseModel = require('../models/Expense');
        expect(ExpenseModel.create).not.toHaveBeenCalled();
      });
    });
  
    describe('getExpensesByFirebaseUid', () => {
      it('should return expenses for a user', async () => {
        // Mock dependencies
        const mockExpenses = [
          {
            _id: 'expense123',
            firebaseUid: 'firebase123',
            amount: 100,
            payee: 'Grocery Store',
            category: 'Food',
            frequency: 'Just once',
            date: new Date(),
          },
          {
            _id: 'expense456',
            firebaseUid: 'firebase123',
            amount: 50,
            payee: 'Gas Station',
            category: 'Transportation',
            frequency: 'Just once',
            date: new Date(),
          },
        ];
        
        const ExpenseModel = require('../models/Expense');
        ExpenseModel.find.mockResolvedValue(mockExpenses);
        
        // Call the function
        const result = await ExpenseService.getExpensesByFirebaseUid('firebase123');
        
        // Assertions
        expect(ExpenseModel.find).toHaveBeenCalledWith({ firebaseUid: 'firebase123' });
        expect(result).toEqual(mockExpenses);
      });
  
      it('should return empty array if no expenses found', async () => {
        // Mock dependencies
        const ExpenseModel = require('../models/Expense');
        ExpenseModel.find.mockResolvedValue([]);
        
        // Call the function
        const result = await ExpenseService.getExpensesByFirebaseUid('firebase123');
        
        // Assertions
        expect(ExpenseModel.find).toHaveBeenCalledWith({ firebaseUid: 'firebase123' });
        expect(result).toEqual([]);
      });
    });
  
    describe('updateExpense', () => {
      it('should update an expense successfully', async () => {
        // Mock dependencies
        const mockExpense = {
          _id: 'expense123',
          firebaseUid: 'firebase123',
          amount: 150,
          payee: 'Updated Grocery Store',
          category: 'Food',
          frequency: 'Just once',
          date: new Date(),
        };
        
        const ExpenseModel = require('../models/Expense');
        ExpenseModel.findById.mockResolvedValue({
          _id: 'expense123',
          firebaseUid: 'firebase123',
          amount: 100,
          payee: 'Grocery Store',
          category: 'Food',
          frequency: 'Just once',
          date: new Date(),
        });
        ExpenseModel.findByIdAndUpdate.mockResolvedValue(mockExpense);
        
        // Call the function
        const result = await ExpenseService.updateExpense('expense123', 'firebase123', {
          amount: 150,
          payee: 'Updated Grocery Store',
        });
        
        // Assertions
        expect(ExpenseModel.findById).toHaveBeenCalledWith('expense123');
        expect(ExpenseModel.findByIdAndUpdate).toHaveBeenCalledWith(
          'expense123',
          {
            amount: 150,
            payee: 'Updated Grocery Store',
          },
          { new: true }
        );
        expect(result).toEqual(mockExpense);
      });
  
      it('should throw an error if expense not found', async () => {
        // Mock dependencies
        const ExpenseModel = require('../models/Expense');
        ExpenseModel.findById.mockResolvedValue(null);
        
        // Call the function and expect it to throw
        await expect(ExpenseService.updateExpense('expense123', 'firebase123', {
          amount: 150,
        })).rejects.toThrow('Expense not found');
        
        // Assertions
        expect(ExpenseModel.findById).toHaveBeenCalledWith('expense123');
        expect(ExpenseModel.findByIdAndUpdate).not.toHaveBeenCalled();
      });
  
      it('should throw an error if user does not own the expense', async () => {
        // Mock dependencies
        const ExpenseModel = require('../models/Expense');
        ExpenseModel.findById.mockResolvedValue({
          _id: 'expense123',
          firebaseUid: 'otherFirebaseUid',
          amount: 100,
          payee: 'Grocery Store',
          category: 'Food',
          frequency: 'Just once',
          date: new Date(),
        });
        
        // Call the function and expect it to throw
        await expect(ExpenseService.updateExpense('expense123', 'firebase123', {
          amount: 150,
        })).rejects.toThrow('Unauthorized: You do not own this expense');
        
        // Assertions
        expect(ExpenseModel.findById).toHaveBeenCalledWith('expense123');
        expect(ExpenseModel.findByIdAndUpdate).not.toHaveBeenCalled();
      });
    });
  });