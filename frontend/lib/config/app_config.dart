// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : app_config.dart
// Description   : Central app configuration — backend base URL.
//                 Change this one line when IP changes or when
//                 deploying to Cloud Run.
// First Written : 12-06-2026
// Edited on     : 12-06-2026
// ============================================

class AppConfig {
  // Deployed backend on Google Cloud Run — permanent, no longer needs
  // updating when WiFi/network changes (unlike local IP testing).
  static const String baseUrl = 'https://finwise-backend-503806083081.asia-southeast1.run.app/api';

  // Local development IPs (kept for reference — uncomment to test locally again)
  //static const String baseUrl = 'http://192.168.100.15:3000/api';
  //static const String baseUrl = 'http://172.20.10.2:3000/api';
}
