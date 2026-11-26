import 'package:get/get.dart';

import '../repositories/group_profile_repository.dart';

class GroupProfileViewModel extends GetxController {
  GroupProfileViewModel({GroupProfileRepository? repository})
    : _repository = repository ?? GroupProfileRepositoryImpl();

  final GroupProfileRepository _repository;

  String get currentUserUid => _repository.currentUserUid;

  Stream<GroupProfileChatData> watchGroup(String chatId) {
    return _repository.watchGroup(chatId);
  }

  Stream<GroupProfileMediaDocsPreview> watchMediaDocsPreview(String chatId) {
    return _repository.watchMediaDocsPreview(chatId);
  }

  Future<void> clearGroupChatHistory(String chatId) {
    return _repository.clearGroupChatHistory(chatId);
  }

  Future<void> leaveGroup({required String chatId, required String uid}) {
    return _repository.leaveGroup(chatId: chatId, uid: uid);
  }

  Future<void> updateGroupName({required String chatId, required String name}) {
    return _repository.updateGroupName(chatId: chatId, name: name);
  }

  Future<String> uploadGroupAvatar({
    required String chatId,
    required String filePath,
  }) {
    return _repository.uploadGroupAvatar(chatId: chatId, filePath: filePath);
  }

  Future<void> setAdmin({
    required String chatId,
    required String uid,
    required bool value,
  }) {
    return _repository.setAdmin(chatId: chatId, uid: uid, value: value);
  }

  Future<void> removeMember({required String chatId, required String uid}) {
    return _repository.removeMember(chatId: chatId, uid: uid);
  }
}
