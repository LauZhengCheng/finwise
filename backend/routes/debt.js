// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : debt.js
// Description   : Debt routes — GET, POST, PATCH, DELETE
// First Written : 17-06-2026
// Edited on     : 17-06-2026
// ============================================

const express = require('express');
const router = express.Router();
const authenticateUser = require('../middleware/auth');
const { getDebts, createDebt, updateDebt, deleteDebt, getStrategy } = require('../controllers/debtController');

router.use(authenticateUser);

router.get('/', getDebts);
router.get('/strategy', getStrategy);
router.post('/', createDebt);
router.patch('/:id', updateDebt);
router.delete('/:id', deleteDebt);

module.exports = router;
