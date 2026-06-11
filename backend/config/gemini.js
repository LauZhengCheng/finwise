// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : gemini.js
// Description   : Initialises Google GenAI client for FinWise backend
//                 Using Vertex AI via Application Default Credentials
// First Written : 23-05-2026
// Edited on     : 24-05-2026
// ============================================

//import official Google Gemini SDK
const { GoogleGenAI } = require('@google/genai');

//initialize authenticated Gemini connection client
const ai = new GoogleGenAI({
  vertexai: true,
  project: process.env.GOOGLE_CLOUD_PROJECT,
  location: process.env.GOOGLE_CLOUD_LOCATION,
});

const geminiModel = 'gemini-2.5-flash';

module.exports = { ai, geminiModel };