// __tests__/budget.service.test.js

// Mock dependencies
jest.mock('../models/Budget', () => ({
    find: jest.fn(),
    findById: jest.fn(),
    create: jest.fn(),
    findByIdAndUpdate: jest.fn(),
    findByIdAndDelete: jest.fn(),
  }));
  
  jest.mock('../models/Expense', () => ({
    find: jest.fn(),
    aggregate: jest.fn(),
  }));
  
  // Import the service (adjust the path as needed)
  const BudgetService = require('../services/budget.service');
  
  describe('Budget Service', () => {
    beforeEach(() => {
      jest.clearAllMocks();
    });
  
    describe('createBudget', () => {
      it('should create a new budget successfully', async () => {
        // Mock dependencies
        const mockBudget = {
          _id: 'budget123',
          firebaseUid: 'firebase123',
          category: 'Food',
          budget: 500,
          spent: 0,
          date: new Date(),
        };
        
        const BudgetModel = require('../models/Budget');
        BudgetModel.create.mockResolvedValue(mockBudget);
        
        // Call the function
        const result = await BudgetService.createBudget({
          firebaseUid: 'firebase123',
          category: 'Food',
          budget: 500,
        });
        
        // Assertions
        expect(BudgetModel.create).toHaveBeenCalledWith({
          firebaseUid: 'firebase123',
          category: 'Food',
          budget: 500,
          spent: 0,
          date: expect.any(Date),
        });
        expect(result).toEqual(mockBudget);
      });
  
      it('should throw an error if budget amount is negative', async () => {
        // Call the function and expect it to throw
        await expect(BudgetService.createBudget({
          firebaseUid: 'firebase123',
          category: 'Food',
          budget: -500,
        })).rejects.toThrow('Budget amount must be positive');
        
        // Assertions
        const BudgetModel = require('../models/Budget');
        expect(BudgetModel.create).not.toHaveBeenCalled();
      });
    });
  
    describe('getBudgetsByFirebaseUid', () => {
      it('should return budgets for a user', async () => {
        // Mock dependencies
        const mockBudgets = [
          {
            _id: 'budget123',
            firebaseUid: 'firebase123',
            category: 'Food',
            budget: 500,
            spent: 0,
            date: new Date(),
          },
          {
            _id: 'budget456',
            firebaseUid: 'firebase123',
            category: 'Transportation',
            budget: 300,
            spent: 0,
            date: new Date(),
          },
        ];
        
        const BudgetModel = require('../models/Budget');
        BudgetModel.find.mockResolvedValue(mockBudgets);
        
        // Call the function
        const result = await BudgetService.getBudgetsByFirebaseUid('firebase123');
        
        // Assertions
        expect(BudgetModel.find).toHaveBeenCalledWith({ firebaseUid: 'firebase123' });
        expect(result).toEqual(mockBudgets);
      });
  
      it('should return empty array if no budgets found', async () => {
        // Mock dependencies
        const BudgetModel = require('../models/Budget');
        BudgetModel.find.mockResolvedValue([]);
        
        // Call the function
        const result = await BudgetService.getBudgetsByFirebaseUid('firebase123');
        
        // Assertions
        expect(BudgetModel.find).toHaveBeenCalledWith({ firebaseUid: 'firebase123' });
        expect(result).toEqual([]);
      });
    });
  
    describe('updateBudget', () => {
      it('should update a budget successfully', async () => {
        // Mock dependencies
        const mockBudget = {
          _id: 'budget123',
          firebaseUid: 'firebase123',
          category: 'Food',
          budget: 600,
          spent: 100,
          date: new Date(),
        };
        
        const BudgetModel = require('../models/Budget');
        BudgetModel.findById.mockResolvedValue({
          _id: 'budget123',
          firebaseUid: 'firebase123',
          category: 'Food',
          budget: 500,
          spent: 100,
          date: new Date(),
        });
        BudgetModel.findByIdAndUpdate.mockResolvedValue(mockBudget);
        
        // Call the function
        const result = await BudgetService.updateBudget('budget123', 'firebase123', {
          budget: 600,
        });
        
        // Assertions
        expect(BudgetModel.findById).toHaveBeenCalledWith('budget123');
        expect(BudgetModel.findByIdAndUpdate).toHaveBeenCalledWith(
          'budget123',
          { budget: 600 },
          { new: true }
        );
        expect(result).toEqual(mockBudget);
      });
  
      it('should throw an error if budget not found', async () => {
        // Mock dependencies
        const BudgetModel = require('../models/Budget');
        BudgetModel.findById.mockResolvedValue(null);
        
        // Call the function and expect it to throw
        await expect(BudgetService.updateBudget('budget123', 'firebase123', {
          budget: 600,
        })).rejects.toThrow('Budget not found');
        
        // Assertions
        expect(BudgetModel.findById).toHaveBeenCalledWith('budget123');
        expect(BudgetModel.findByIdAndUpdate).not.toHaveBeenCalled();
      });
  
      it('should throw an error if user does not own the budget', async () => {
        // Mock dependencies
        const BudgetModel = require('../models/Budget');
        BudgetModel.findById.mockResolvedValue({
          _id: 'budget123',
          firebaseUid: 'otherFirebaseUid',
          category: 'Food',
          budget: 500,
          spent: 100,
          date: new Date(),
        });
        
        // Call the function and expect it to throw
        await expect(BudgetService.updateBudget('budget123', 'firebase123', {
          budget: 600,
        })).rejects.toThrow('Unauthorized: You do not own this budget');
        
        // Assertions
        expect(BudgetModel.findById).toHaveBeenCalledWith('budget123');
        expect(BudgetModel.findByIdAndUpdate).not.toHaveBeenCalled();
      });
    });
  });