import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core/firebase_core.dart' as firebase_core;
import 'package:cloud_firestore/cloud_firestore.dart';

import 'admin_dashboard/admin_dashboard_app.dart';
import 'firebase_options.dart';
import 'package:cipta_vera_mandiri_digital/app/services/chat_notification_service.dart';
import 'package:cipta_vera_mandiri_digital/app/services/app_notification_service.dart';
import 'package:cipta_vera_mandiri_digital/app/services/notification_service.dart';
import 'package:cipta_vera_mandiri_digital/app/services/push_notification_service.dart';
import 'package:cipta_vera_mandiri_digital/app/services/user_activity_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  String? fatalError;

  try {
    if (!kIsWeb) {
      await dotenv.load(fileName: '.env');
    }
  } catch (e, st) {
    debugPrint('❌ Failed to load .env (continuing): ${e.toString()}');
    debugPrint(st.toString());
  }

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    if (!kIsWeb) {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    }
  } catch (e, st) {
    String detail = e.toString();
    if (e is firebase_core.FirebaseException) {
      detail = '${e.code}: ${e.message ?? e.code}';
    }
    debugPrint('❌ Firebase init failed [${e.runtimeType}]: $detail');
    debugPrint(st.toString());
    fatalError = 'Gagal inisialisasi Firebase: $detail';
  }

  if (fatalError == null) {
    try {
      await NotificationService().init();
      await PushNotificationService().init();
      ChatNotificationService().start();
      await AppNotificationService().start();
      UserActivityNotificationService().start();
    } catch (e, st) {
      debugPrint('❌ Admin bootstrap failed: ${e.toString()}');
      debugPrint(st.toString());
      fatalError = 'Gagal menyiapkan layanan admin: ${e.toString()}';
    }
  }

  if (fatalError != null) {
    runApp(_FatalErrorApp(message: fatalError!));
  } else {
    runApp(const AdminDashboardApp());
  }
}

class _FatalErrorApp extends StatelessWidget {
  const _FatalErrorApp({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF111827), Color(0xFF1F2937)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline,
                      size: 48, color: Colors.redAccent),
                  const SizedBox(height: 12),
                  const Text(
                    'Gagal memuat admin portal',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
