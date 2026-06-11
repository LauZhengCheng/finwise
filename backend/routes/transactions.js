// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : transactions.js
// Description   : Transaction routes — initiate, execute, cancel
// First Written : 21-May-2026
// Edited on     : 06-06-2026
// ============================================

const express = require('express');
const router = express.Router();
const authenticateUser = require('../middleware/auth');
const { initiateTransaction, executeTransaction, cancelTransaction, categorizeTransaction, getTransactionHistory } = require('../controllers/transactionController');

router.get('/status', (req, res) => {
  res.json({ success: true, message: 'Transactions route working' });
});

// POST /api/transactions/initiate
// Categorise merchant, check balance, run Goal Guardian
router.post('/initiate',
  (req, res, next) => authenticateUser(req, res, next),
  (req, res) => initiateTransaction(req, res)
);

// POST /api/transactions/execute
// User proceeded after Goal Guardian alert — deduct vault + write transaction
router.post('/execute',
  (req, res, next) => authenticateUser(req, res, next),
  (req, res) => executeTransaction(req, res)
);

// POST /api/transactions/cancel
// User cancelled after Goal Guardian alert — write cancelled transaction
router.post('/cancel',
  (req, res, next) => authenticateUser(req, res, next),
  (req, res) => cancelTransaction(req, res)
);

// POST /api/transactions/categorize
// AI suggests a vault — no money moved, user can change before confirming
router.post('/categorize',
  (req, res, next) => authenticateUser(req, res, next),
  (req, res) => categorizeTransaction(req, res)
);

// GET /api/transactions/history
router.get('/history',
  (req, res, next) => authenticateUser(req, res, next),
  (req, res) => getTransactionHistory(req, res)
);

module.exports = router;
