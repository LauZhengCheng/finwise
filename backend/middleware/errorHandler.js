// ============================================
// Programmer : Lau Zheng Cheng (TP071393)
// Program Name : errorHandler.js
// Description : Centralized error handling middleware for API routes
// First Written : 21-May-2026
// Edited on : 21-May-2026
// ============================================

const errorHandler = (err, req, res, next) => {
    console.error('Error:', err.message);
    
    //send error response to frontend
    res.status(err.status || 500).json({
        success: false,
        error: err.message || 'Internal server error',
        timestamp: new Date().toISOString()
    });
};

//export errorHandler for use in other files
module.exports = errorHandler;