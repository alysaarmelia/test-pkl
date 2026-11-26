import 'package:get/get.dart';

import '../repositories/starred_messages_repository.dart';

class StarredMessageItem {
  const StarredMessageItem({
    required this.id,
    required this.type,
    required this.title,
    required this.time,
  });

  final String id;
  final String type;
  final String title;
  final DateTime? time;
}

class StarredMessagesViewModel extends GetxController {
  StarredMessagesViewModel({StarredMessagesRepository? repository})
    : _repository = repository ?? StarredMessagesRepositoryImpl();

  final StarredMessagesRepository _repository;

  String get currentUserUid => _repository.currentUserUid;

  Future<String?> resolveChatId({String? chatId, String? peerUid}) {
    return _repository.resolveChatId(chatId: chatId, peerUid: peerUid);
  }

  Stream<List<StarredMessageRecord>> watchStarredBy({
    required String chatId,
    required String myUid,
  }) {
    return _repository.watchStarredBy(chatId: chatId, myUid: myUid);
  }

  Stream<List<StarredMessageRecord>> watchLegacyStarred({
    required String chatId,
  }) {
    return _repository.watchLegacyStarred(chatId: chatId);
  }

  Future<void> removeStar({
    required String chatId,
    required String messageId,
    required String myUid,
  }) {
    return _repository.removeStar(
      chatId: chatId,
      messageId: messageId,
      myUid: myUid,
    );
  }

  List<StarredMessageItem> combineAndFilter({
    required List<StarredMessageRecord> byRecords,
    required List<StarredMessageRecord> legacyRecords,
    required String myUid,
  }) {
    final merged = <String, StarredMessageRecord>{};
    for (final record in legacyRecords) {
      merged[record.id] = record;
    }
    for (final record in byRecords) {
      merged[record.id] = record;
    }

    final combined = merged.values
        .where((record) {
          if (record.isDeleted) return false;
          if (myUid.isNotEmpty && record.deletedFor.contains(myUid)) {
            return false;
          }
          return true;
        })
        .toList(growable: false);

    final sorted = [...combined]
      ..sort((a, b) {
        final ad = a.sortTime ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bd = b.sortTime ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bd.compareTo(ad);
      });

    return sorted
        .map((record) {
          final title = record.type == 'text'
              ? (record.text.isEmpty ? '[teks kosong]' : record.text)
              : '[${record.type.toUpperCase()}]';
          return StarredMessageItem(
            id: record.id,
            type: record.type,
            title: title,
            time: record.displayTime,
          );
        })
        .toList(growable: false);
  }

  String? formatTime(DateTime? dt) {
    if (dt == null) return null;
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year.toString();
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$d/$m/$y • $hh:$mm';
  }
}
