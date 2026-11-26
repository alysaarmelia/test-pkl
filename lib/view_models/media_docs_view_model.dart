import 'package:get/get.dart';

import '../repositories/media_docs_repository.dart';

class MediaDocsViewModel extends GetxController {
  MediaDocsViewModel({MediaDocsRepository? repository})
    : _repository = repository ?? MediaDocsRepositoryImpl();

  final MediaDocsRepository _repository;

  Stream<List<MediaDocsMessageRecord>> watchMediaMessages(String chatId) {
    return _repository.watchMediaMessages(chatId);
  }

  Stream<List<MediaDocsMessageRecord>> watchFileMessages(String chatId) {
    return _repository.watchFileMessages(chatId);
  }

  Future<void> deleteMessages({
    required String chatId,
    required List<String> messageIds,
  }) {
    return _repository.deleteMessages(chatId: chatId, messageIds: messageIds);
  }

  Future<List<String>> loadIdsForTab({
    required String chatId,
    required int tabIndex,
  }) {
    return _repository.fetchMessageIdsByType(
      chatId: chatId,
      type: tabIndex == 0 ? 'image' : 'file',
    );
  }
}
