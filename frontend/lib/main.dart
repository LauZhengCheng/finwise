// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : main.dart
// Description   : Main entry point for FYP Neobanking Flutter app.
//                 Initialises Supabase, Firebase, Riverpod, and app routing.
// First Written : 21-May-2026
// Edited on     : 18-06-2026
// ============================================

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/app_router.dart';
import 'config/app_theme.dart';
import 'providers/notification_provider.dart';
import 'services/api/notification_api.dart';

// Handles FCM messages when app is fully terminated (background isolate)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

// GoRouter instance — allows navigation from notification taps
GoRouter? _appRouter;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Supabase.initialize(
      url: 'https://maucwiaximkmnqbevbgu.supabase.co',
      anonKey: 'sb_publishable_kjxTC10qBOY1fMgAPBj1cQ_8VmZxr4B',
    );

    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Foreground notification channel (Android)
    await _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (details) {
        // Tap on foreground notification — navigate to route in payload
        _appRouter?.go('/chat');
      },
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          'aion_channel',
          'Aion Notifications',
          description: 'Proactive messages from your financial advisor Aion',
          importance: Importance.high,
        ));
  } catch (e) {
    runApp(MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFF0D0B08),
        body: Center(child: Text(
          'Failed to initialise app.\nPlease check your connection and restart.\n\n$e',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        )),
      ),
    ));
    return;
  }

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _registerFcmToken();
    _setupFcmHandlers();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _registerFcmToken();
      if (Supabase.instance.client.auth.currentUser != null) {
        ref.read(notificationProvider.notifier).fetch();
      }
    }
  }

  void _setupFcmHandlers() {
    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification == null) return;
      _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'aion_channel',
            'Aion Notifications',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
        ),
        payload: message.data['route'] ?? '/chat',
      );
      if (Supabase.instance.client.auth.currentUser != null) {
        ref.read(notificationProvider.notifier).fetch();
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _appRouter?.go('/chat');
      if (Supabase.instance.client.auth.currentUser != null) {
        ref.read(notificationProvider.notifier).fetch();
      }
    });
  }

  Future<void> _registerFcmToken() async {
    try {
      // Only register if user is logged in
      if (Supabase.instance.client.auth.currentUser == null) return;
      await FirebaseMessaging.instance.requestPermission();
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await NotificationApi().registerToken(token);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    _appRouter = router;
    return MaterialApp.router(
      title: 'FinWise',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: router,
    );
  }
}
