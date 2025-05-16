// routes/incomeRoutes.js
const express = require('express');
const router = express.Router();
const Income = require('../models/Income');
const verifyFirebaseToken = require('../middleware/verifyFirebaseToken');
const { getDateRangeFromMonth } = require('../utils/dateUtils');

// Add income
router.post('/', verifyFirebaseToken, async (req, res) => {
  const { amount, source, description, date, frequency, category } = req.body;
  try {
    const income = new Income({
      firebaseUid: req.user.uid,
      amount,
      source,
      description,
      date: date ? new Date(date) : new Date(), // fallback to now
      frequency,
      category,
      active: true
    });
    await income.save();
    res.status(201).json({ message: 'Income added successfully', income });
  } catch (err) {
    res.status(500).json({ message: `Error adding income: ${err.message}` });
  }
});

// Get all income for the authenticated user (optionally filter by month)
router.get('/', verifyFirebaseToken, async (req, res) => {
  try {
    const userUid = req.user.uid;
    const { month } = req.query;
    const dateRange = getDateRangeFromMonth(month);
    const query = { firebaseUid: userUid };
    if (dateRange) {
      query.date = { $gte: dateRange.startDate, $lt: dateRange.endDate };
    }
    const income = await Income.find(query).sort({ date: 1 });
    res.status(200).json(income);
  } catch (err) {
    res.status(500).json({ message: `Error fetching income: ${err.message}` });
  }
});

// Update an income entry
router.put('/:id', verifyFirebaseToken, async (req, res) => {
  const { id } = req.params;
  const { amount, source, description, date, frequency, category, active } = req.body;
  try {
    const updatedIncome = await Income.findOneAndUpdate(
      { _id: id, firebaseUid: req.user.uid },
      {
        amount,
        source,
        description,
        date: date ? new Date(date) : new Date(),
        frequency,
        category,
        active,
      },
      { new: true }
    );
    if (!updatedIncome) {
      return res.status(404).json({ message: 'Income not found' });
    }
    res.status(200).json({ message: 'Income updated successfully', updatedIncome });
  } catch (err) {
    res.status(500).json({ message: `Error updating income: ${err.message}` });
  }
});

// Delete an income entry
router.delete('/:id', verifyFirebaseToken, async (req, res) => {
  const { id } = req.params;
  try {
    const deletedIncome = await Income.findOneAndDelete({ _id: id, firebaseUid: req.user.uid });
    if (!deletedIncome) {
      return res.status(404).json({ message: 'Income not found' });
    }
    res.status(200).json({ message: 'Income deleted successfully' });
  } catch (err) {
    res.status(500).json({ message: `Error deleting income: ${err.message}` });
  }
});

module.exports = router;
