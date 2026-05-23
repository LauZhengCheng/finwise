// ============================================
// Programmer : Lau Zheng Cheng (TP071393)
// Program Name : supabase.js
// Description : Configure Supabase client for database interactions
// First Written : 21-May-2026
// Edited on : 21-May-2026
// ============================================

//import Supabase SDK (official tool/library for communicating with Supabase) into backend
const { createClient } = require('@supabase/supabase-js');

//read secret values from .env file
const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_ANON_KEY;

if (!supabaseUrl || !supabaseKey) {
    throw new Error('Missing Supabase environment variables');
}

//create live connection object to Supabase
const supabase = createClient(supabaseUrl, supabaseKey);

//export supabase object for use in other files (make private object to be public accessible)
module.exports = supabase;