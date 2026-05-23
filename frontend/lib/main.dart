// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : main.dart
// Description   : Main entry point for FYP Neobanking Flutter app.
//                 Initialises Supabase, Riverpod, and app routing.
// First Written : 21-May-2026
// Edited on     : 21-May-2026
// ============================================

import 'package:flutter/material.dart'; //Import Flutter UI
import 'package:flutter_riverpod/flutter_riverpod.dart'; //Import Riverpod state management system
import 'package:supabase_flutter/supabase_flutter.dart'; //Import Supabase Flutter SDK
import 'config/app_router.dart'; //Import screen navigation rules
import 'config/app_theme.dart'; //Import global app styling

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized(); //fully initialize Flutter engine before running async code (Supabase initialization)

  await Supabase.initialize( //initialize Supabase backend project
    url: 'https://maucwiaximkmnqbevbgu.supabase.co',
    anonKey: 'sb_publishable_kjxTC10qBOY1fMgAPBj1cQ_8VmZxr4B',
  );

  runApp(//start rendering(drawing) Flutter UI
    const ProviderScope( //turn on Riverpod system for whole app (allow sharing state between screens)
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) { //build the main app UI
    final router = ref.watch(appRouterProvider); //listen to routing state from Riverpod

    return MaterialApp.router( //create a MaterialApp widget that handles routing and theme management
      title: 'FinWise',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
    );
  }
}