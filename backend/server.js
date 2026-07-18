// ============================================
// Programmer : Lau Zheng Cheng (TP071393)
// Program Name : server.js
// Description : Main server entry point for FYP Neobanking
// First Written : 21-May-2026
// Edited on : 18-06-2026
// ============================================

// ============================================
// FYP Neobanking — Main Server Entry Point
// ============================================
require('dotenv').config(); //load values from .env file into process.env
const express = require('express'); //use Express.js to create API server
const cors = require('cors'); //allow frontend and backend to communicate
const mongoose = require('mongoose');

// Start background workers (production only — BullMQ polls Redis constantly)
// In development, startup setTimeout calls below handle the initial data fetch
if (process.env.NODE_ENV === 'production') {
  require('./workers/marketDataWorker');
  require('./workers/newsFetchWorker');
  require('./workers/fdScrapeWorker');
  require('./workers/dealsScrapeWorker');
}

// On startup — populate Redis cache immediately so Aion has data right away
// In production, Cloud Scheduler handles recurring refresh via /api/jobs/trigger
const { refreshAllMarketData } = require('./services/marketDataService');
const { fetchAndSummariseNews } = require('./services/newsService');
const { scrapeFDRates, scrapeDeals } = require('./services/scrapeService');
const { checkAllBillsOnStartup } = require('./controllers/billController');
setTimeout(() => {
  refreshAllMarketData().catch(e => console.error('[Startup] Market data error:', e.message));
}, 3000);

setTimeout(() => {
  fetchAndSummariseNews().catch(e => console.error('[Startup] News error:', e.message));
}, 10000);

setTimeout(() => {
  scrapeFDRates().catch(e => console.error('[Startup] FD scrape error:', e.message));
}, 15000);

setTimeout(() => {
  scrapeDeals().catch(e => console.error('[Startup] Deals scrape error:', e.message));
}, 20000);

setTimeout(() => {
  checkAllBillsOnStartup().catch(e => console.error('[Startup] Bills check error:', e.message));
}, 5000);

//load all API endpoints from separate files
const authRoutes = require('./routes/auth');
const vaultRoutes = require('./routes/vaults');
const transactionRoutes = require('./routes/transactions');
const aiRoutes = require('./routes/ai');
const incomeRoutes = require('./routes/income');
const debtRoutes = require('./routes/debt');
const investRoutes = require('./routes/invest');
const billRoutes = require('./routes/bills');
const achievementRoutes = require('./routes/achievements');
const financeRoutes = require('./routes/finance');
const jobRoutes = require('./routes/jobs');
const transferRoutes = require('./routes/transfer');
const notificationRoutes = require('./routes/notifications');

//centralized error handling
const errorHandler = require('./middleware/errorHandler');

//create backend Express application and set 3000 as default port
const app = express();
const PORT = process.env.PORT || 3000;

// Middleware that connects FE and BE, and converts JSON requests to JavaScript objects
app.use(cors());
app.use(express.json());

// Security middleware
const helmet = require('helmet');
const mongoSanitize = require('express-mongo-sanitize');
app.use(helmet());
app.use((req, res, next) => {
  if (req.body) mongoSanitize.sanitize(req.body);
  if (req.params) mongoSanitize.sanitize(req.params);
  next();
});

const rateLimit = require('express-rate-limit');
app.use('/api/', rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 2000,
  message: { error: 'Too many requests, please try again later' },
}));

// Health check - simple endpoint to verify server alive
app.get('/health', (req, res) => {
    const mongoStates = { 0: 'disconnected', 1: 'connected', 2: 'connecting', 3: 'disconnecting' };
    res.json({
        status: 'ok',
        timestamp: new Date().toISOString(),
        mongodb: mongoStates[mongoose.connection.readyState] || 'unknown',
    });
});

// all Routes start with /api/...
app.use('/api/auth', authRoutes);
app.use('/api/vaults', vaultRoutes);
app.use('/api/transactions', transactionRoutes);
app.use('/api/ai', aiRoutes);
app.use('/api/income', incomeRoutes);
app.use('/api/debt', debtRoutes);
app.use('/api/invest', investRoutes);
app.use('/api/bills', billRoutes);
app.use('/api/achievements', achievementRoutes);
app.use('/api/finance', financeRoutes);
app.use('/api/jobs', jobRoutes);
app.use('/api/transfer', transferRoutes);
app.use('/api/notifications', notificationRoutes);

// Error handler - must be last
app.use(errorHandler);

//start backend server and listen for incoming requests
app.listen(PORT, () => {
    console.log(`FYP Neobanking API running on port ${PORT}`);
});

//export backend app for use in other files
module.exports = app;