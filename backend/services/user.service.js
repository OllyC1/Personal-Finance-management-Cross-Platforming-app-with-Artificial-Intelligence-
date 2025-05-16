// services/user.service.js
const UserModel = require('../models/User');

const UserService = {
  async registerUser(userData) {
    const { email, username, firebaseUid } = userData;
    
    // Check if user already exists
    const existingUser = await UserModel.findOne({ email });
    if (existingUser) {
      throw new Error('User with this email already exists');
    }
    
    // Create user
    const user = await UserModel.create({
      email,
      username,
      firebaseUid,
    });
    
    return user;
  },
  
  async getUserByFirebaseUid(firebaseUid) {
    const user = await UserModel.findOne({ firebaseUid });
    if (!user) {
      throw new Error('User not found');
    }
    
    return user;
  },
  
  async updateUser(firebaseUid, userData) {
    const user = await UserModel.findOne({ firebaseUid });
    if (!user) {
      throw new Error('User not found');
    }
    
    const updatedUser = await UserModel.findByIdAndUpdate(
      user._id,
      userData,
      { new: true }
    );
    
    return updatedUser;
  },
};

module.exports = UserService;