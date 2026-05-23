// ============================================
// Programmer : Lau Zheng Cheng (TP071393)
// Program Name : auth.js
// Description : Handle authentication routes for FYP Neobanking
// First Written : 21-May-2026
// Edited on : 21-May-2026
// ============================================

//load Express framework
const express = require('express');
const router = express.Router();

// Auth routes handled by Supabase directly
// This file handles any custom auth logic

//health check endpoint to verify auth route is working
router.get('/status', (req, res) => {
    //send JSON response back to frontend/client
    res.json({ success: true, message: 'Auth route working' });
});

//export router for use in other files
module.exports = router;