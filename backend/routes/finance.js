// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : finance.js
// Description   : Finance routes — health score, net worth, spending forecast
// First Written : 17-06-2026
// Edited on     : 17-06-2026
// ============================================

const express = require('express');
const router = express.Router();
const authenticateUser = require('../middleware/auth');
const { getHealthScore, getInsuranceCoverage, updateInsuranceCoverage, getNetWorth, getSpendingForecast, getFinancialNews, getFDRates, getDeals, getProtectionRecommendations, getTickerData } = require('../controllers/financeController');

router.use(authenticateUser);

router.get('/health-score', getHealthScore);
router.get('/insurance', getInsuranceCoverage);
router.patch('/insurance', updateInsuranceCoverage);
router.get('/net-worth', getNetWorth);
router.get('/spending-forecast', getSpendingForecast);
router.get('/news', getFinancialNews);
router.get('/fd-rates', getFDRates);
router.get('/deals', getDeals);
router.get('/protection', getProtectionRecommendations);
router.get('/ticker', getTickerData);

module.exports = router;
