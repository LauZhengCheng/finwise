// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : income.js
// Description   : Income routes — salary staging (2-step) and general deposit
// First Written : 21-May-2026
// Edited on     : 18-06-2026
// ============================================

const express = require('express');
const router = express.Router();
const authenticateUser = require('../middleware/auth');
const { injectIncome, depositToVault, stageIncome, applyIncome, getPendingIncome } = require('../controllers/incomeController');

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

// POST /api/income/deposit
// General deposit: adds amount to a specific vault (current_balance + allocated_amount)
router.post(
  '/deposit',
  (req, res, next) => authenticateUser(req, res, next),
  (req, res) => depositToVault(req, res)
);

// POST /api/income/stage
// 2-step salary: saves pending record, does NOT update vault balances yet
router.post(
  '/stage',
  (req, res, next) => authenticateUser(req, res, next),
  (req, res) => stageIncome(req, res)
);

// POST /api/income/apply
// 2-step salary: applies staged income — carry_over or sweep mode
router.post(
  '/apply',
  (req, res, next) => authenticateUser(req, res, next),
  (req, res) => applyIncome(req, res)
);

// GET /api/income/pending
// Returns any staged-but-not-applied income injection for the current user
router.get(
  '/pending',
  (req, res, next) => authenticateUser(req, res, next),
  (req, res) => getPendingIncome(req, res)
);

module.exports = router;
