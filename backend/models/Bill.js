// models/Bill.js
const mongoose = require('mongoose');

const BillSchema = new mongoose.Schema({
  firebaseUid: { type: String, required: true },
  name: { type: String, required: true },
  amount: { type: Number, required: true },
  dueDate: { type: Date, required: true },
  // Add any other fields you like (e.g. recurring frequency)
});

module.exports = mongoose.model('Bill', BillSchema);
