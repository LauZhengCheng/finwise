// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : jobs.js
// Description   : Route for Cloud Scheduler webhook trigger.
//                 No auth middleware here — jobController handles its own
//                 bearer token check (Cloud Scheduler, not user JWT).
// First Written : 18-06-2026
// Edited on     : 18-06-2026
// ============================================

const express = require('express');
const router = express.Router();
const { triggerJob } = require('../controllers/jobController');

router.post('/trigger', triggerJob);

module.exports = router;
