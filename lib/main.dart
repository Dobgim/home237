import 'dart:async';
import 'package:flutter/foundation.dart'; // kIsWeb
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'firebase_options.dart';
import 'splash_screen.dart';
import 'theme_notifier.dart';
import 'locale_notifier.dart';
import 'app_localizations.dart';
import 'auth_service.dart';
import 'inactivity_service.dart';
import 'messages_screen.dart';
import 'services/remote_config_service.dart';

// Global navigator key to allow navigation from outside widget tree (e.g. AuthService)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("Handling background message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase
  await Supabase.initialize(
    url: 'https://sazsantjnginauetpttf.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNhenNhbnRqbmdpbmF1ZXRwdHRmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzA5MTM3MzEsImV4cCI6MjA4NjQ4OTczMX0.FAwkhuiJe-DgwanWtkL_cL2ChH79q8LYyYrMxHtuMJ4',
  );
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 🔑 Fetch secrets (Groq API key etc.) from Firebase Remote Config
  await remoteConfigService.initialize();

  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => authService),
        ChangeNotifierProvider(create: (_) => ThemeNotifier()),
        ChangeNotifierProvider(create: (_) => LocaleNotifier()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeNotifier = context.watch<ThemeNotifier>();
    final localeNotifier = context.watch<LocaleNotifier>();

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'HomeFinder237',
      debugShowCheckedModeBanner: false,

      // 🌍 Language
      locale: localeNotifier.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      // 🎨 Theme
      themeMode: themeNotifier.themeMode,
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.teal,
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.black87),
          titleTextStyle: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        cardColor: Colors.white,
        colorScheme: const ColorScheme.light(
          primary: Colors.teal,
          secondary: Color(0xFF3B82F6),
          surface: Colors.white,
          background: Colors.white,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: Colors.black87,
          onBackground: Colors.black87,
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.teal,
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: const Color(0xFF1E1E1E),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF2D2D2D),
          foregroundColor: Colors.white,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        cardColor: const Color(0xFF2D2D2D),
        colorScheme: const ColorScheme.dark(
          primary: Colors.teal,
          secondary: Color(0xFF3B82F6),
          surface: Color(0xFF2D2D2D),
          background: Color(0xFF1E1E1E),
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: Colors.white,
          onBackground: Colors.white,
        ),
      ),

      home: const SplashScreen(),
      // Wraps every route with touch detection for inactivity tracking
      builder: (context, child) => InactivityWrapper(child: child ?? const SizedBox.shrink()),
    );
  }
}

/// Wraps the entire app widget tree. Listens for auth state changes to
/// start/stop the inactivity timer, and intercepts all pointer events
/// to reset the 5-minute idle countdown.
class InactivityWrapper extends StatefulWidget {
  final Widget child;
  const InactivityWrapper({required this.child, super.key});

  @override
  State<InactivityWrapper> createState() => _InactivityWrapperState();
}

class _InactivityWrapperState extends State<InactivityWrapper> {
  StreamSubscription<RemoteMessage>? _messagingSubscription;

  @override
  void initState() {
    super.initState();
    authService.addListener(_onAuthChanged);
    // If session was already restored before this widget mounted, start now
    if (authService.isLoggedIn) inactivityService.start();

    if (!kIsWeb) {
      // Listen for foreground notifications
      _messagingSubscription = FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint("Foreground message received: ${message.messageId}");
        final notification = message.notification;
        if (notification != null) {
          _showForegroundNotification(notification.title ?? "New Message", notification.body ?? "");
        }
      });
    }
  }

  void _onAuthChanged() {
    if (authService.isLoggedIn) {
      inactivityService.start();
    } else {
      inactivityService.stop();
    }
  }

  void _showForegroundNotification(String title, String body) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.chat_bubble, color: Color(0xFF3B82F6), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    body,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? const Color(0xFF2D2D2D) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 6,
        action: SnackBarAction(
          label: 'View',
          textColor: const Color(0xFF3B82F6),
          onPressed: () {
            navigatorKey.currentState?.push(
              MaterialPageRoute(builder: (context) => const MessagesScreen()),
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    authService.removeListener(_onAuthChanged);
    inactivityService.stop();
    _messagingSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => inactivityService.onUserActivity(),
      onPointerMove: (_) => inactivityService.onUserActivity(),
      child: widget.child,
    );
  }
}
