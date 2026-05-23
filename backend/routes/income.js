// ============================================
// Programmer : Lau Zheng Cheng (TP071393)
// Program Name : income.js
// Description : Handle income routes for FYP Neobanking
// First Written : 21-May-2026
// Edited on : 21-May-2026
// ============================================

//load Express framework
const express = require('express');
const router = express.Router();

//health check endpoint to verify income route is working
router.get('/status', (req, res) => {
    //send JSON response back to frontend/client
    res.json({ success: true, message: 'Income route working' });
});

//export router for use in other files
module.exports = router;