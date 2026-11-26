import 'package:get/get.dart';

import '../repositories/chat_page_repository.dart';

class ChatPageViewModel extends GetxController {
  ChatPageViewModel({ChatPageRepository? repository})
    : _repository = repository ?? ChatPageRepositoryImpl();

  final ChatPageRepository _repository;

  String get currentUserUid => _repository.currentUserUid;

  Future<Map<String, dynamic>> fetchChatData(String chatId) {
    return _repository.fetchChatData(chatId);
  }

  Future<String?> getPeerUid({required String chatId, required String myUid}) {
    return _repository.getPeerUid(chatId: chatId, myUid: myUid);
  }

  Future<String> fetchUserDisplayName(String uid) {
    return _repository.fetchUserDisplayName(uid);
  }

  Future<ChatPageUserProfile> fetchUserProfile(String uid) {
    return _repository.fetchUserProfile(uid);
  }

  Stream<ChatPageUserProfile> watchUserProfile(String uid) {
    return _repository.watchUserProfile(uid);
  }

  Future<void> setPresence({required String uid, required bool online}) {
    return _repository.setPresence(uid: uid, online: online);
  }

  Future<void> markRead({required String chatId, required String myUid}) {
    return _repository.markRead(chatId: chatId, myUid: myUid);
  }

  Future<ChatPageSendResult> sendTextMessage({
    required String chatId,
    required String myUid,
    required String text,
    required bool isGroup,
    required List<dynamic> memberIds,
    String? peerUid,
    String? clientMessageId,
    String? replyToId,
    String? replyToText,
    bool? replyToFromMe,
  }) {
    return _repository.sendTextMessage(
      chatId: chatId,
      myUid: myUid,
      text: text,
      isGroup: isGroup,
      memberIds: memberIds,
      peerUid: peerUid,
      clientMessageId: clientMessageId,
      replyToId: replyToId,
      replyToText: replyToText,
      replyToFromMe: replyToFromMe,
    );
  }

  Future<void> setTyping({
    required String chatId,
    required String myUid,
    required bool active,
  }) {
    return _repository.setTyping(chatId: chatId, myUid: myUid, active: active);
  }

  Stream<Map<String, DateTime?>> watchTyping(String chatId) {
    return _repository.watchTyping(chatId);
  }

  Future<ChatPageCreateMessageResult> createFilePlaceholder({
    required String chatId,
    required String myUid,
    required bool isGroup,
    required List<dynamic> memberIds,
    required String fileName,
    required int fileSize,
    String? peerUid,
  }) {
    return _repository.createFilePlaceholder(
      chatId: chatId,
      myUid: myUid,
      isGroup: isGroup,
      memberIds: memberIds,
      fileName: fileName,
      fileSize: fileSize,
      peerUid: peerUid,
    );
  }

  Future<ChatPageCreateMessageResult> createImagePlaceholder({
    required String chatId,
    required String myUid,
    required bool isGroup,
    required List<dynamic> memberIds,
    String? peerUid,
  }) {
    return _repository.createImagePlaceholder(
      chatId: chatId,
      myUid: myUid,
      isGroup: isGroup,
      memberIds: memberIds,
      peerUid: peerUid,
    );
  }

  Future<String> uploadChatFile({
    required String chatId,
    required String messageId,
    required String filePath,
    required String fileName,
    void Function(double progress)? onProgress,
  }) {
    return _repository.uploadChatFile(
      chatId: chatId,
      messageId: messageId,
      filePath: filePath,
      fileName: fileName,
      onProgress: onProgress,
    );
  }

  Future<String> uploadChatImage({
    required String chatId,
    required String messageId,
    required String filePath,
    void Function(double progress)? onProgress,
  }) {
    return _repository.uploadChatImage(
      chatId: chatId,
      messageId: messageId,
      filePath: filePath,
      onProgress: onProgress,
    );
  }

  Future<void> deleteChatImage({
    required String chatId,
    required String messageId,
  }) {
    return _repository.deleteChatImage(chatId: chatId, messageId: messageId);
  }

  Future<void> updateMessageFields({
    required String chatId,
    required String messageId,
    required Map<String, dynamic> data,
  }) {
    return _repository.updateMessageFields(
      chatId: chatId,
      messageId: messageId,
      data: data,
    );
  }

  List<ChatPageMessageRecord> getCachedMessages({
    required String chatId,
    int limit = 100,
  }) {
    return _repository.getCachedMessages(chatId: chatId, limit: limit);
  }

  Stream<List<ChatPageMessageRecord>> watchMessages({
    required String chatId,
    int limit = 100,
  }) {
    return _repository.watchMessages(chatId: chatId, limit: limit);
  }

  Future<void> markMessageDelivered({
    required String chatId,
    required String messageId,
  }) {
    return _repository.markMessageDelivered(
      chatId: chatId,
      messageId: messageId,
    );
  }

  Future<void> markMessagesDelivered({
    required String chatId,
    required Iterable<String> messageIds,
  }) {
    return _repository.markMessagesDelivered(
      chatId: chatId,
      messageIds: messageIds,
    );
  }

  Future<List<ChatPageForwardTarget>> getForwardTargets({
    required String myUid,
    String? excludeChatId,
    int limit = 30,
  }) {
    return _repository.getForwardTargets(
      myUid: myUid,
      excludeChatId: excludeChatId,
      limit: limit,
    );
  }

  Future<void> forwardMessage({
    required String targetChatId,
    required String myUid,
    required String type,
    required String text,
    String? imageUrl,
  }) {
    return _repository.forwardMessage(
      targetChatId: targetChatId,
      myUid: myUid,
      type: type,
      text: text,
      imageUrl: imageUrl,
    );
  }

  Future<void> deleteMessageForMe({
    required String chatId,
    required String messageId,
    required String myUid,
  }) {
    return _repository.deleteMessageForMe(
      chatId: chatId,
      messageId: messageId,
      myUid: myUid,
    );
  }

  Future<void> deleteMessageForAll({
    required String chatId,
    required String messageId,
  }) {
    return _repository.deleteMessageForAll(
      chatId: chatId,
      messageId: messageId,
    );
  }

  Future<Map<String, dynamic>> fetchMessage({
    required String chatId,
    required String messageId,
  }) {
    return _repository.fetchMessage(chatId: chatId, messageId: messageId);
  }

  Future<void> clearMessageMedia({
    required String chatId,
    required String messageId,
  }) {
    return _repository.clearMessageMedia(chatId: chatId, messageId: messageId);
  }

  Future<void> toggleStar({
    required String chatId,
    required String messageId,
    required bool value,
    required String myUid,
  }) {
    return _repository.toggleStar(
      chatId: chatId,
      messageId: messageId,
      value: value,
      myUid: myUid,
    );
  }
}
