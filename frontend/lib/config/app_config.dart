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
  // Local development — update this when your IP changes
  // After Cloud Run deployment, replace with the deployed URL permanently
  
  static const String baseUrl = 'http://192.168.100.15:3000/api';
  //static const String baseUrl = 'http://172.20.10.2:3000/api';
}
