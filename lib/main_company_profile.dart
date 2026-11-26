import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'company_profile/company_profile_app.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } catch (error, stackTrace) {
    debugPrint(
      '⚠️ Gagal memuat file .env untuk CompanyProfile: $error\n$stackTrace',
    );
    rethrow;
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
    debugPrint('✅ Firebase siap untuk CompanyProfile');
  } catch (error, stackTrace) {
    debugPrint(
      '⚠️ Firebase init gagal untuk CompanyProfile: $error\n$stackTrace',
    );
    // Biarkan app tetap jalan; CompanyHomePage akan mencoba lagi.
  }
  runApp(const CompanyProfileApp());
}
