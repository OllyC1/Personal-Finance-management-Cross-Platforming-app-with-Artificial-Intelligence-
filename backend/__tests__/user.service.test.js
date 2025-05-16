// __tests__/user.service.test.js
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');

// Mock dependencies
jest.mock('jsonwebtoken');
jest.mock('bcryptjs');
jest.mock('../models/User', () => ({
  findOne: jest.fn(),
  findById: jest.fn(),
  create: jest.fn(),
  findByIdAndUpdate: jest.fn(),
}));

// Import the service (adjust the path as needed)
const UserService = require('../services/user.service');

describe('User Service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('registerUser', () => {
    it('should register a new user successfully', async () => {
      // Mock dependencies
      const mockUser = {
        _id: 'user123',
        firebaseUid: 'firebase123',
        email: 'test@example.com',
        username: 'testuser',
      };
      
      const UserModel = require('../models/User');
      UserModel.findOne.mockResolvedValue(null);
      UserModel.create.mockResolvedValue(mockUser);
      
      // Call the function
      const result = await UserService.registerUser({
        firebaseUid: 'firebase123',
        email: 'test@example.com',
        username: 'testuser',
      });
      
      // Assertions
      expect(UserModel.findOne).toHaveBeenCalledWith({ email: 'test@example.com' });
      expect(UserModel.create).toHaveBeenCalledWith({
        firebaseUid: 'firebase123',
        email: 'test@example.com',
        username: 'testuser',
      });
      expect(result).toEqual(mockUser);
    });

    it('should throw an error if user already exists', async () => {
      // Mock dependencies
      const UserModel = require('../models/User');
      UserModel.findOne.mockResolvedValue({ email: 'test@example.com' });
      
      // Call the function and expect it to throw
      await expect(UserService.registerUser({
        firebaseUid: 'firebase123',
        email: 'test@example.com',
        username: 'testuser',
      })).rejects.toThrow('User with this email already exists');
      
      // Assertions
      expect(UserModel.findOne).toHaveBeenCalledWith({ email: 'test@example.com' });
      expect(UserModel.create).not.toHaveBeenCalled();
    });
  });

  describe('getUserByFirebaseUid', () => {
    it('should return a user by firebase UID', async () => {
      // Mock dependencies
      const mockUser = {
        _id: 'user123',
        firebaseUid: 'firebase123',
        email: 'test@example.com',
        username: 'testuser',
      };
      
      const UserModel = require('../models/User');
      UserModel.findOne.mockResolvedValue(mockUser);
      
      // Call the function
      const result = await UserService.getUserByFirebaseUid('firebase123');
      
      // Assertions
      expect(UserModel.findOne).toHaveBeenCalledWith({ firebaseUid: 'firebase123' });
      expect(result).toEqual(mockUser);
    });

    it('should throw an error if user not found', async () => {
      // Mock dependencies
      const UserModel = require('../models/User');
      UserModel.findOne.mockResolvedValue(null);
      
      // Call the function and expect it to throw
      await expect(UserService.getUserByFirebaseUid('firebase123'))
        .rejects.toThrow('User not found');
      
      // Assertions
      expect(UserModel.findOne).toHaveBeenCalledWith({ firebaseUid: 'firebase123' });
    });
  });
});