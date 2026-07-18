// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : invest.js
// Description   : Investment routes — CRUD + risk score + analysis
// First Written : 24-06-2026
// Edited on     : 24-06-2026
// ============================================

const express = require('express');
const router = express.Router();
const authenticateUser = require('../middleware/auth');
const { getInvestments, createInvestment, updateInvestment, deleteInvestment, saveAllInvestments, getPortfolioRisk, getPortfolioAnalysis, getCryptoPrices, getStockQuote, getListings } = require('../controllers/investController');

router.use(authenticateUser);

router.get('/', getInvestments);
router.get('/risk', getPortfolioRisk);
router.get('/analysis', getPortfolioAnalysis);
router.get('/crypto-prices', getCryptoPrices);
router.get('/quote/:ticker', getStockQuote);
router.get('/listings', getListings);
router.post('/', createInvestment);
router.post('/save-all', saveAllInvestments);
router.patch('/:id', updateInvestment);
router.delete('/:id', deleteInvestment);

module.exports = router;
