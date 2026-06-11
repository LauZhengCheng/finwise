// ============================================
// Programmer : Lau Zheng Cheng (TP071393)
// Program Name : ai.js
// Description : Handle AI routes for FYP Neobanking
// First Written : 21-May-2026
// Edited on : 21-May-2026
// ============================================

//load Express framework
const express = require('express');
const router = express.Router();
const authenticateUser = require('../middleware/auth');
const aiController = require('../controllers/aiController');

//health check endpoint to verify AI route is working
router.get('/status', (req, res) => {
    //send JSON response back to frontend/client
    res.json({ success: true, message: 'AI route working' });
});

// ─────────────────────────────────────────────
// ONBOARDING ROUTES
// ─────────────────────────────────────────────

// POST /api/ai/onboarding/chat
router.post('/onboarding/chat', (req, res, next) => authenticateUser(req, res, next), (req, res) => aiController.onboardingChat(req, res));

// POST /api/ai/onboarding/confirm-vaults
router.post('/onboarding/confirm-vaults', (req, res, next) => authenticateUser(req, res, next), (req, res) => aiController.confirmVaults(req, res));

// ─────────────────────────────────────────────
// ADVISORY CHAT ROUTES
// ─────────────────────────────────────────────

// POST /api/ai/chat — send a message to Aria
router.post('/chat', (req, res, next) => authenticateUser(req, res, next), (req, res) => aiController.advisoryChat(req, res));

// GET /api/ai/chat/history — load all past chat messages for display
router.get('/chat/history', (req, res, next) => authenticateUser(req, res, next), (req, res) => aiController.getChatHistory(req, res));

// POST /api/ai/chat/summarize — summarise previous session, update key_insights boundary
router.post('/chat/summarize', (req, res, next) => authenticateUser(req, res, next), (req, res) => aiController.summarizeSession(req, res));

// POST /api/ai/chat/apply-vault-changes — execute confirmed vault plan update
router.post('/chat/apply-vault-changes', (req, res, next) => authenticateUser(req, res, next), (req, res) => aiController.applyVaultChanges(req, res));

// GET /api/ai/profile — full user profile: onboarding + AI conclusions + allocation history
router.get('/profile', (req, res, next) => authenticateUser(req, res, next), (req, res) => aiController.getMyProfile(req, res));

//export router for use in other files
module.exports = router;