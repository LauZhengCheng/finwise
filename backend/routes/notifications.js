// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : notifications.js (routes)
// Description   : Routes for FCM token registration and notification history.
// First Written : 18-06-2026
// Edited on     : 18-06-2026
// ============================================

const express = require('express');
const router = express.Router();
const authenticateUser = require('../middleware/auth');
const { registerToken, clearToken, getNotificationHistory, markChatOpened } = require('../controllers/notificationController');

router.post('/register-token', authenticateUser, registerToken);
router.delete('/clear-token', authenticateUser, clearToken);
router.get('/history', authenticateUser, getNotificationHistory);
router.post('/mark-chat-opened', authenticateUser, markChatOpened);

module.exports = router;
