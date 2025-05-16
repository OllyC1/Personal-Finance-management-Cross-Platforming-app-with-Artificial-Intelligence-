const mongoose = require("mongoose")

const expenseSchema = new mongoose.Schema({
  firebaseUid: {
    type: String,
    required: true,
  },
  amount: {
    type: Number,
    required: true,
  },
  payee: {
    type: String,
    required: true,
  },
  category: {
    type: String,
    required: true,
  },
  frequency: {
    type: String,
    required: true,
  },
  description: {
    type: String,
  },
  dueDate: {
    type: Date,
  },
  date: {
    type: Date,
    default: Date.now,
  },
  active: {
    type: Boolean,
    default: true,
  },
  
  goalId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: "Goal",
    
  },
  history: {
    type: Array,
    default: [],
  },
})

module.exports = mongoose.model("Expense", expenseSchema)