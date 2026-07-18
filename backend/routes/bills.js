// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : bills.js
// Description   : Bills routes — GET, POST, PATCH, DELETE
// First Written : 17-06-2026
// Edited on     : 17-06-2026
// ============================================

const express = require('express');
const router = express.Router();
const authenticateUser = require('../middleware/auth');
const { getBills, createBill, updateBill, deleteBill } = require('../controllers/billController');

router.use(authenticateUser);

router.get('/', getBills);
router.post('/', createBill);
router.patch('/:id', updateBill);
router.delete('/:id', deleteBill);

module.exports = router;
