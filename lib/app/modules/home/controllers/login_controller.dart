import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:cipta_vera_mandiri_digital/view_models/auth_credentials_view_model.dart';
import 'package:cipta_vera_mandiri_digital/repositories/auth_credentials_repository.dart';

class LoginController extends GetxController {
  LoginController({AuthCredentialsViewModel? viewModel})
    : _viewModel = viewModel ?? AuthCredentialsViewModel();

  // Form field controller
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  // Loading state
  var isLoading = false.obs;
  final AuthCredentialsViewModel _viewModel;

  // Function login
  Future<void> login() async {
    String email = emailController.text.trim();
    String password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      showSnackbar("Error", "Email & Password tidak boleh kosong");
      return;
    }

    isLoading.value = true;

    try {
      final result = await _viewModel.login(email: email, password: password);

      if (result.status == LoginFlowStatus.success) {
        showSnackbar("Sukses", "Login berhasil");
        navigateTo(result.profileCompleted ? '/home' : '/complete-profile');
        return;
      }

      if (result.status == LoginFlowStatus.emailNotVerified) {
        showSnackbar("Error", "Email belum diverifikasi. Cek inbox Anda.");
        return;
      }

      if (result.status == LoginFlowStatus.authError) {
        showSnackbar(
          "Error",
          _mapAuthError(result.authErrorCode, result.message),
        );
        return;
      }

      showSnackbar(
        "Error",
        result.message ?? "Terjadi kesalahan. Silakan coba lagi.",
      );
    } catch (e) {
      showSnackbar("Error", "Terjadi kesalahan: $e");
    } finally {
      isLoading.value = false;
    }
  }

  @protected
  void showSnackbar(String title, String message) {
    Get.snackbar(title, message);
  }

  @protected
  void navigateTo(String routeName) {
    Get.offAllNamed(routeName);
  }

  String _mapAuthError(String? code, String? fallback) {
    switch (code) {
      case 'user-not-found':
        return 'Pengguna tidak ditemukan';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Password salah';
      case 'invalid-email':
        return 'Format email tidak valid';
      case 'too-many-requests':
        return 'Terlalu banyak percobaan. Coba lagi nanti.';
      default:
        return fallback ?? 'Terjadi kesalahan';
    }
  }
}
