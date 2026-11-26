
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Setup current user sebagai super admin dengan semua roles
Future<void> setupCurrentUserAsAdmin() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    throw Exception('User not authenticated');
  }

  final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
  
  // Set semua admin roles
  await userRef.set({
    'roles': {
      'superAdmin': true,
      'admin': true,
      'attendance': true,
      'requests': true,
      'calendar': true,
      'documents': true,
      'material': true,
      'users': true,
      'companyProfile': true,
    },
  }, SetOptions(merge: true));

  print('✅ User ${user.email} setup sebagai Super Admin');
}

/// Setup calendar role only untuk current user
Future<void> setupCurrentUserCalendarRole() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    throw Exception('User not authenticated');
  }

  final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
  
  await userRef.set({
    'roles': {
      'calendar': true,
    },
  }, SetOptions(merge: true));

  print('✅ User ${user.email} setup dengan calendar role');
}

/// Verify user roles
Future<Map<String, dynamic>> checkCurrentUserRoles() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    throw Exception('User not authenticated');
  }

  final doc = await FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .get();
  
  final data = doc.data();
  final roles = data?['roles'] as Map<String, dynamic>? ?? {};
  
  print('📋 User: ${user.email}');
  print('📋 UID: ${user.uid}');
  print('📋 Roles: $roles');
  
  return roles;
}
