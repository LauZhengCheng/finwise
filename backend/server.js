// ============================================
// Programmer : Lau Zheng Cheng (TP071393)
// Program Name : server.js
// Description : Main server entry point for FYP Neobanking
// First Written : 21-May-2026
// Edited on : 21-May-2026
// ============================================

// ============================================
// FYP Neobanking — Main Server Entry Point
// ============================================
require('dotenv').config(); //load values from .env file into process.env
const express = require('express'); //use Express.js to create API server
const cors = require('cors'); //allow frontend and backend to communicate

//load all API endpoints from separate files
const authRoutes = require('./routes/auth');
const vaultRoutes = require('./routes/vaults');
const transactionRoutes = require('./routes/transactions');
const aiRoutes = require('./routes/ai');
const incomeRoutes = require('./routes/income');

//centralized error handling
const errorHandler = require('./middleware/errorHandler');

//create backend Express application and set 3000 as default port
const app = express();
const PORT = process.env.PORT || 3000;

// Middleware that connects FE and BE, and converts JSON requests to JavaScript objects
app.use(cors());
app.use(express.json());

// Health check - simple endpoint to verify server alive
app.get('/health', (req, res) => {
    res.json({ 
        status: 'ok', 
        message: 'FYP Neobanking API is running',
        timestamp: new Date().toISOString()
    });
});

// all Routes start with /api/...
app.use('/api/auth', authRoutes);
app.use('/api/vaults', vaultRoutes);
app.use('/api/transactions', transactionRoutes);
app.use('/api/ai', aiRoutes);
app.use('/api/income', incomeRoutes);

// Error handler - must be last
app.use(errorHandler);

//start backend server and listen for incoming requests
app.listen(PORT, () => {
    console.log(`FYP Neobanking API running on port ${PORT}`);
});

//export backend app for use in other files
module.exports = app;