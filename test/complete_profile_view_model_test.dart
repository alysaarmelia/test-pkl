import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:cipta_vera_mandiri_digital/repositories/complete_profile_repository.dart';
import 'package:cipta_vera_mandiri_digital/view_models/complete_profile_view_model.dart';

class _FakeCompleteProfileRepository implements CompleteProfileRepository {
  _FakeCompleteProfileRepository({
    this.uid,
    this.email,
    CompleteProfilePinResult? pinResult,
  }) : _pinResult =
           pinResult ??
           const CompleteProfilePinResult(success: true, pin: 'CV123456M');

  String? uid;
  String? email;
  final CompleteProfilePinResult _pinResult;
  CompleteProfileSaveRequest? lastSaveRequest;
  bool throwOnSave = false;
  String uploadUrl = 'https://example.com/profile.jpg';
  int uploadCalls = 0;

  @override
  String? get currentUserUid => uid;

  @override
  String? get currentUserEmail => email;

  @override
  Future<CompleteProfilePinResult> ensureUserPin() async {
    return _pinResult;
  }

  @override
  Future<void> saveProfile(CompleteProfileSaveRequest request) async {
    if (throwOnSave) {
      throw const CompleteProfileRepositoryException('Gagal simpan');
    }
    lastSaveRequest = request;
  }

  @override
  Future<String> uploadProfilePicture({
    required File image,
    required String uid,
  }) {
    uploadCalls++;
    return Future<String>.value(uploadUrl);
  }
}

void main() {
  test('loadOrGeneratePin mengembalikan hasil dari repository', () async {
    final repository = _FakeCompleteProfileRepository(
      pinResult: const CompleteProfilePinResult(
        success: true,
        pin: 'CV000001M',
      ),
    );
    final viewModel = CompleteProfileViewModel(repository: repository);

    final result = await viewModel.loadOrGeneratePin();

    expect(result.success, isTrue);
    expect(result.pin, 'CV000001M');
  });

  test('saveProfile warning saat tidak ada sesi user', () async {
    final repository = _FakeCompleteProfileRepository(uid: null, email: null);
    final viewModel = CompleteProfileViewModel(repository: repository);

    final feedback = await viewModel.saveProfile(
      name: 'Nama',
      division: 'Finance',
      pin: 'CV123456M',
    );

    expect(feedback.type, CompleteProfileFeedbackType.warning);
    expect(feedback.message, contains('Sesi pengguna'));
  });

  test('saveProfile success dan menyimpan payload ter-normalisasi', () async {
    final repository = _FakeCompleteProfileRepository(
      uid: 'u-1',
      email: 'user@example.com',
    );
    final viewModel = CompleteProfileViewModel(repository: repository);

    final feedback = await viewModel.saveProfile(
      name: '  Nizar  ',
      division: ' Finance ',
      pin: '  CV123456M ',
    );

    expect(feedback.type, CompleteProfileFeedbackType.success);
    expect(repository.lastSaveRequest, isNotNull);
    expect(repository.lastSaveRequest!.uid, 'u-1');
    expect(repository.lastSaveRequest!.name, 'Nizar');
    expect(repository.lastSaveRequest!.division, 'Finance');
    expect(repository.lastSaveRequest!.pin, 'CV123456M');
    expect(repository.lastSaveRequest!.email, 'user@example.com');
    expect(repository.uploadCalls, 0);
  });

  test('saveProfile error saat repository gagal', () async {
    final repository = _FakeCompleteProfileRepository(
      uid: 'u-1',
      email: 'user@example.com',
    )..throwOnSave = true;
    final viewModel = CompleteProfileViewModel(repository: repository);

    final feedback = await viewModel.saveProfile(
      name: 'Nizar',
      division: 'Finance',
      pin: 'CV123456M',
    );

    expect(feedback.type, CompleteProfileFeedbackType.error);
    expect(feedback.message, contains('Gagal simpan'));
  });
}
