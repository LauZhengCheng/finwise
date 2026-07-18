// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : achievements.js
// Description   : Achievements route — GET derived achievements
// First Written : 17-06-2026
// Edited on     : 17-06-2026
// ============================================

const express = require('express');
const router = express.Router();
const authenticateUser = require('../middleware/auth');
const { getAchievements } = require('../controllers/achievementController');

router.use(authenticateUser);

router.get('/', getAchievements);

module.exports = router;
