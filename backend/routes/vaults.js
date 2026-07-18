// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : vaults.js
// Description   : Vault routes — Active Pilot transfer
// First Written : 21-May-2026
// Edited on     : 06-06-2026
// ============================================

const express = require('express');
const router = express.Router();
const authenticateUser = require('../middleware/auth');
const { transferVault, archiveGoal, unarchiveGoal } = require('../controllers/vaultController');

router.get('/status', (req, res) => {
  res.json({ success: true, message: 'Vaults route working' });
});

// POST /api/vaults/transfer
// Active Pilot: move money between vaults
router.post('/transfer',
  (req, res, next) => authenticateUser(req, res, next),
  (req, res) => transferVault(req, res)
);

// POST /api/vaults/:id/archive
// Hide a completed goal from the dashboard
router.post('/:id/archive',
  (req, res, next) => authenticateUser(req, res, next),
  (req, res) => archiveGoal(req, res)
);

// POST /api/vaults/:id/unarchive
// Restore an archived goal to the dashboard
router.post('/:id/unarchive',
  (req, res, next) => authenticateUser(req, res, next),
  (req, res) => unarchiveGoal(req, res)
);

module.exports = router;
