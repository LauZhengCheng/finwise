// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : transfer.js (routes)
// Description   : P2P transfer routes — send, allocate, and history.
// First Written : 18-06-2026
// Edited on     : 18-06-2026
// ============================================

const express = require('express');
const router = express.Router();
const authenticate = require('../middleware/auth');
const { lookupRecipient, sendTransfer, allocateTransfer, getTransferHistory } = require('../controllers/transferController');

router.get('/lookup', authenticate, lookupRecipient);
router.post('/send', authenticate, sendTransfer);
router.post('/allocate', authenticate, allocateTransfer);
router.get('/history', authenticate, getTransferHistory);

module.exports = router;
