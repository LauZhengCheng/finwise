// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : auth.js
// Description   : Authentication middleware for FYP Neobanking.
//                 Verifies Supabase JWT tokens on protected routes. “Is this API request coming from a valid logged-in user?”
// First Written : 21-May-2026
// Edited on     : 21-May-2026
// ============================================

const supabase = require('../config/supabase');

//Express middleware that runs BEFORE protected route executes
const authenticateUser = async (req, res, next) => {
    try {
        //Reads incoming HTTP header
        const authHeader = req.headers.authorization;

        //Standard JWT authentication format starts with Bearer TOKEN_HERE
        if (!authHeader || !authHeader.startsWith('Bearer ')) {
            return res.status(401).json({
                success: false,
                error: 'Missing or invalid authorization header'
            });
        }

        const token = authHeader.split(' ')[1];

        //Verify Token With Supabase
        const { data: { user }, error } = await supabase.auth.getUser(token);

        if (error || !user) {
            return res.status(401).json({
                success: false,
                error: 'Invalid or expired token'
            });
        }

        req.user = user;
        next(); //authentication passed, continue request flow
    } catch (error) {
        return res.status(500).json({
            success: false,
            error: 'Authentication error'
        });
    }
};

module.exports = authenticateUser;