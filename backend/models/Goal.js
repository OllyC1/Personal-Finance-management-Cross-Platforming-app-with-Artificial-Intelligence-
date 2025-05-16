const mongoose = require('mongoose');

const goalSchema = new mongoose.Schema({
  firebaseUid: { type: String, required: true },
  name: { type: String, required: true },
  amount: { type: Number, required: true },
  progress: { type: Number, default: 0 },
  initialProgress: { type: Number, default: 0,},
  type: { type: String, required: true }, // 'Savings' or 'Debt'
  duration: { type: Number, default: 1 },   // Duration in months
  date: { type: Date, default: Date.now },
});

module.exports = mongoose.model('Goal', goalSchema);
