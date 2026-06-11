// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : income.js
// Description   : Income routes — salary deposit / traffic controller
// First Written : 21-May-2026
// Edited on     : 06-06-2026
// ============================================

const express = require('express');
const router = express.Router();
const authenticateUser = require('../middleware/auth');
const { injectIncome } = require('../controllers/incomeController');

// Health check
router.get('/status', (req, res) => {
  res.json({ success: true, message: 'Income route working' });
});

// POST /api/income/inject
// Traffic Controller: splits salary across vaults by allocation_percentage
router.post(
  '/inject',
  (req, res, next) => authenticateUser(req, res, next),
  (req, res) => injectIncome(req, res)
);

module.exports = router;
