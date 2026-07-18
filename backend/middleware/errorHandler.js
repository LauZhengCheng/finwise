// ============================================
// Programmer : Lau Zheng Cheng (TP071393)
// Program Name : errorHandler.js
// Description : Centralized error handling middleware for API routes
// First Written : 21-May-2026
// Edited on : 21-May-2026
// ============================================

const errorHandler = (err, req, res, next) => {
    console.error(`[Error] ${req.method} ${req.path}:`, err.message);

    const status = err.status || 500;
    const isProduction = process.env.NODE_ENV === 'production';

    res.status(status).json({
        success: false,
        error: isProduction && status === 500
          ? 'Internal server error'
          : err.message || 'Internal server error',
    });
};

//export errorHandler for use in other files
module.exports = errorHandler;