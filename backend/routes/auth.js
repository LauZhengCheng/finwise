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
const authenticateUser = require('../middleware/auth');
const supabaseService = require('../services/supabaseService');

// Auth routes handled by Supabase directly
// This file handles any custom auth logic

//health check endpoint to verify auth route is working
router.get('/status', (req, res) => {
    //send JSON response back to frontend/client
    res.json({ success: true, message: 'Auth route working' });
});

// Check onboarding status
router.get('/onboarding-status', authenticateUser, async (req, res) => {
    try {
        const isComplete = await supabaseService.checkOnboardingComplete(req.user.id);
        res.json({
            success: true,
            onboardingComplete: isComplete
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            error: error.message
        });
    }
});

// Get user profile
router.get('/profile', authenticateUser, async (req, res) => {
    try {
        const profile = await supabaseService.getProfile(req.user.id);
        res.json({
            success: true,
            data: profile
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            error: error.message
        });
    }
});
// Update user profile (name and/or phone number)
router.patch('/profile', authenticateUser, async (req, res) => {
    try {
        const { full_name, phone_number } = req.body;
        const updates = {};
        if (full_name !== undefined) updates.full_name = full_name;
        if (phone_number !== undefined) updates.phone_number = phone_number;

        if (Object.keys(updates).length === 0) {
            return res.status(400).json({ success: false, error: 'No fields to update' });
        }

        const profile = await supabaseService.updateProfile(req.user.id, updates);
        res.json({ success: true, data: profile });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

//export router for use in other files
module.exports = router;