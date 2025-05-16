const mongoose = require('mongoose');

const incomeSchema = new mongoose.Schema({
  firebaseUid: { type: String, required: true },
  amount: Number,
  source: String,
  description: String,
  date: { type: Date, default: Date.now },
  frequency: { type: String, default: 'Just once' },
  category: { type: String, default: 'Other' },
  active: { type: Boolean, default: true },
  history: [{ type: mongoose.Schema.Types.Mixed }]
});

module.exports = mongoose.model('Income', incomeSchema);
