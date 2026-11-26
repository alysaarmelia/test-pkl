import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../repositories/homepage_repository.dart';

class HomePageViewModel extends GetxController {
  HomePageViewModel({HomePageRepository? repository})
    : _repository = repository ?? HomePageRepositoryImpl();

  final HomePageRepository _repository;

  int _currentIndex = 0;
  Timer? _sessionTimer;
  VoidCallback? _onSessionExpired;

  int get currentIndex => _currentIndex;

  @override
  void onInit() {
    super.onInit();
    unawaited(_initSessionWatcher());
  }

  @override
  void onClose() {
    _sessionTimer?.cancel();
    _sessionTimer = null;
    _onSessionExpired = null;
    super.onClose();
  }

  void bindSessionExpiredHandler(VoidCallback onSessionExpired) {
    _onSessionExpired = onSessionExpired;
  }

  void setCurrentIndex(int index) {
    if (_currentIndex == index) return;
    _currentIndex = index;
    _notify();
  }

  void resetToHome() {
    setCurrentIndex(0);
  }

  Future<void> logout() async {
    resetToHome();
    await _handleSessionExpired();
  }

  Future<void> refreshSessionWatcher() {
    return _initSessionWatcher();
  }

  Future<void> _initSessionWatcher() async {
    final remaining = await _repository.remainingSessionTime();
    _sessionTimer?.cancel();
    if (remaining == null) return;

    if (remaining.isNegative || remaining == Duration.zero) {
      await _handleSessionExpired();
    } else {
      _sessionTimer = Timer(remaining, () {
        unawaited(_handleSessionExpired());
      });
    }
  }

  Future<void> _handleSessionExpired() async {
    _sessionTimer?.cancel();
    await _repository.clearSession();
    await _repository.signOut();
    _onSessionExpired?.call();
  }

  void _notify() {
    if (isClosed) return;
    update();
  }
}
