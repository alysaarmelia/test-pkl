import 'package:get/get.dart';

import '../repositories/user_profile_repository.dart';

enum UserProfileFeedbackType { success, info, warning, error, none }

class UserProfileFeedback {
  const UserProfileFeedback({required this.type, required this.message});

  final UserProfileFeedbackType type;
  final String message;
}

class UserProfileViewModel extends GetxController {
  UserProfileViewModel({UserProfileRepository? repository})
    : _repository = repository ?? UserProfileRepositoryImpl();

  final UserProfileRepository _repository;

  String get currentUserUid => _repository.currentUserUid;

  Stream<UserProfilePeerProfile> watchPeerProfile(String peerUid) {
    return _repository.watchPeerProfile(peerUid);
  }

  Stream<bool> watchIsInMyContacts({required String peerUid}) {
    final myUid = currentUserUid;
    if (myUid.isEmpty) return Stream.value(false);
    return _repository.watchIsInMyContacts(myUid: myUid, peerUid: peerUid);
  }

  Future<String?> resolveChatId({required String peerUid}) {
    final myUid = currentUserUid;
    if (myUid.isEmpty || peerUid.isEmpty) return Future.value(null);
    return _repository.resolveChatId(myUid: myUid, peerUid: peerUid);
  }

  Future<UserProfileFeedback> addContactForBoth({
    required String peerUid,
    required UserProfilePeerProfile peerProfile,
  }) async {
    final myUid = currentUserUid;
    final result = await _repository.addContactForBoth(
      myUid: myUid,
      peerUid: peerUid,
      peerProfile: peerProfile,
    );
    switch (result.status) {
      case UserProfileAddContactStatus.success:
        return UserProfileFeedback(
          type: UserProfileFeedbackType.success,
          message: result.message,
        );
      case UserProfileAddContactStatus.partial:
        return UserProfileFeedback(
          type: UserProfileFeedbackType.warning,
          message: result.message,
        );
      case UserProfileAddContactStatus.notLoggedIn:
      case UserProfileAddContactStatus.self:
        return UserProfileFeedback(
          type: UserProfileFeedbackType.warning,
          message: result.message,
        );
      case UserProfileAddContactStatus.failure:
        return UserProfileFeedback(
          type: UserProfileFeedbackType.error,
          message: result.message,
        );
    }
  }

  Future<UserProfileFeedback> clearChatHistory(String chatId) async {
    final result = await _repository.clearChatHistory(chatId);
    return UserProfileFeedback(
      type: result.success
          ? UserProfileFeedbackType.success
          : UserProfileFeedbackType.error,
      message: result.message,
    );
  }

  Stream<UserProfileMediaDocsPreview> watchMediaDocsPreview(String chatId) {
    return _repository.watchMediaDocsPreview(chatId);
  }

  Stream<UserProfileStarredSummary?> watchStarredSummary({
    required String chatId,
    required String myUid,
  }) {
    return _repository.watchStarredSummary(chatId: chatId, myUid: myUid);
  }
}
