import 'package:cipta_vera_mandiri_digital/app/constants/assets.dart';
import 'package:cipta_vera_mandiri_digital/app/modules/home/bindings/shared_preferences.dart';
import 'package:cipta_vera_mandiri_digital/app/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class OnboardingViewModel extends GetxController {
  final pageController = PageController();
  final currentIndex = 0.obs;

  final List<OnboardingContent> contents = [
    OnboardingContent(
      title: "Selamat Datang di CVM Digital",
      description: "Platform digital modern untuk mengelola absensi dan manajemen kehadiran Anda.",
      imageAsset: AppAssets.cvmLogo,
    ),
    OnboardingContent(
      title: "Lokasi & Wajah",
      description: "Lakukan absensi dengan aman menggunakan teknologi Face Recognition dan Geo-location.",
      imageAsset: AppAssets.onboardingFaceLocation,
    ),
    OnboardingContent(
      title: "Pantau Kinerja Real-time",
      description: "Dapatkan informasi terbaru mengenai jadwal, absensi, dan pengumuman secara langsung.",
      imageAsset: AppAssets.onboardingRealtimePerformance,
    ),
  ];

  void onPageChanged(int index) {
    currentIndex.value = index;
  }

  void next() {
    if (currentIndex.value == contents.length - 1) {
      finishOnboarding();
    } else {
      pageController.nextPage(
        duration: const Duration(milliseconds: 600),
        curve: Curves.fastOutSlowIn,
      );
    }
  }

  void skip() {
    finishOnboarding();
  }

  Future<void> finishOnboarding() async {
    await AppPreferences.setFirstTimeCompleted();
    Get.offAllNamed(Routes.LOGIN);
  }

  @override
  void onClose() {
    pageController.dispose();
    super.onClose();
  }
}

class OnboardingContent {
  final String title;
  final String description;
  final IconData? icon;
  final String? imageAsset;

  OnboardingContent({
    required this.title,
    required this.description,
    this.icon,
    this.imageAsset,
  });
}
