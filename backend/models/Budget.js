const mongoose = require("mongoose")

const budgetSchema = new mongoose.Schema({
  firebaseUid: {
    type: String,
    required: true,
  },
  category: {
    type: String,
    required: true,
  },
  budget: {
    type: Number,
    required: true,
  },
  spent: {
    type: Number,
    default: 0,
  },
  rollover: {
    type: Boolean,
    default: false,
  },
  rolloverAmount: {
    type: Number,
    default: 0,
  },
  date: {
    type: Date,
    default: Date.now,
  },
})

// Create a compound index on firebaseUid, category, and date
// Remove any unique constraint to allow multiple budgets for the same category
budgetSchema.index({ firebaseUid: 1, category: 1, date: 1 })

module.exports = mongoose.model("Budget", budgetSchema)

