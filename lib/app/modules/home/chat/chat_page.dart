// Chat detail page (not ChatListPage)
import 'dart:ui';
import 'dart:async';
import 'dart:io';
import 'package:cipta_vera_mandiri_digital/app/modules/home/chat/msg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cipta_vera_mandiri_digital/app/widgets/glass_snack_bar.dart';
import 'package:cipta_vera_mandiri_digital/app/modules/home/chat/user_profile_page.dart';
import 'package:cipta_vera_mandiri_digital/app/modules/home/chat/group_profile_page.dart';
import 'package:cipta_vera_mandiri_digital/app/modules/home/chat/starred_messages_page.dart';
import 'package:cipta_vera_mandiri_digital/app/modules/home/chat/composer.dart';
import 'package:cipta_vera_mandiri_digital/app/modules/home/chat/bubble.dart';
import 'package:cipta_vera_mandiri_digital/app/services/chat_notification_service.dart';
import 'package:cipta_vera_mandiri_digital/app/services/avatar_thumbnail_cache_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';
import 'package:path/path.dart' as p;
import 'package:open_filex/open_filex.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cipta_vera_mandiri_digital/repositories/chat_page_repository.dart';
import 'package:cipta_vera_mandiri_digital/repositories/chat_list_repository.dart';
import 'package:cipta_vera_mandiri_digital/view_models/chat_page_view_model.dart';

const List<Color> _chatBackgroundGradient = <Color>[
  Color(0xFF101529),
  Color(0xFF1C2844),
];
const Color _chatSurfaceSoft = Color.fromRGBO(255, 255, 255, 0.12);
const List<Color> _chatOrbBlue = <Color>[
  Color.fromRGBO(82, 148, 255, 0.34),
  Color.fromRGBO(82, 148, 255, 0),
];
const List<Color> _chatOrbPurple = <Color>[
  Color.fromRGBO(141, 83, 255, 0.28),
  Color.fromRGBO(141, 83, 255, 0),
];
const List<Color> _chatOrbMint = <Color>[
  Color.fromRGBO(72, 233, 205, 0.24),
  Color.fromRGBO(72, 233, 205, 0),
];
const String _sendSoundAsset = 'lib/app/assets/sound/pengirim.mp3';
const String _receiveSoundAsset = 'lib/app/assets/sound/penerima.mp3';

class ChatPage extends StatefulWidget {
  final String? chatId; // null = fallback dummy mode
  final String? peerName;
  final String? peerAvatarUrl;
  final bool isGroup;
  final ChatPageRepository? repository;
  final ChatPageViewModel? viewModel;
  final void Function(String? chatId)? setActiveChat;

  const ChatPage({
    super.key,
    this.chatId,
    this.peerName,
    this.peerAvatarUrl,
    this.isGroup = false,
    this.repository,
    this.viewModel,
    this.setActiveChat,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

// Cache lokal untuk preview media agar tetap instan ketika user keluar-masuk chat
// dalam satu sesi aplikasi (menghindari delay baca SharedPreferences).
final Map<String, Map<String, String>> _localMediaSessionCache = {};
final Map<String, Map<String, _LocalPendingTextMessage>>
_localPendingTextSessionCache =
    <String, Map<String, _LocalPendingTextMessage>>{};

class _LocalPendingTextMessage {
  _LocalPendingTextMessage({
    required this.localId,
    required this.text,
    required this.createdAt,
    this.replyToId,
    this.replyToText,
    this.replyToFromMe,
  });

  final String localId;
  final String text;
  final DateTime createdAt;
  final String? replyToId;
  final String? replyToText;
  final bool? replyToFromMe;
  String? serverMessageId;
}

class _ChatBackground extends StatelessWidget {
  const _ChatBackground();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.expand(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _chatBackgroundGradient,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            _BackgroundOrb(
              top: -90,
              left: -50,
              diameter: 260,
              colors: _chatOrbBlue,
            ),
            _BackgroundOrb(
              top: 140,
              right: -110,
              diameter: 320,
              colors: _chatOrbPurple,
            ),
            _BackgroundOrb(
              bottom: -140,
              left: 80,
              diameter: 360,
              colors: _chatOrbMint,
            ),
          ],
        ),
      ),
    );
  }
}

class _BackgroundOrb extends StatelessWidget {
  const _BackgroundOrb({
    this.top,
    this.left,
    this.right,
    this.bottom,
    required this.diameter,
    required this.colors,
  });

  final double? top;
  final double? left;
  final double? right;
  final double? bottom;
  final double diameter;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: IgnorePointer(
        child: SizedBox(
          width: diameter,
          height: diameter,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: colors, stops: const [0.0, 1.0]),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatPageState extends State<ChatPage> {
  late final ChatPageViewModel _viewModel;
  late final String _viewModelTag;

  void _setActiveChat(String? chatId) {
    final setter = widget.setActiveChat;
    if (setter != null) {
      setter(chatId);
      return;
    }
    ChatNotificationService().setActiveChat(chatId);
  }

  // Fallback cache for resolving user names when memberInfo is incomplete
  final Map<String, String> _userNameCache = {};
  final Set<String> _pendingUserNameFetches = <String>{};
  Timer? _userNameRefreshTimer;
  String? _peerAvatarThumbPath;
  String _peerAvatarThumbUrl = '';

  void _scheduleUserNameRefresh() {
    if (!mounted) return;
    _userNameRefreshTimer?.cancel();
    _userNameRefreshTimer = Timer(const Duration(milliseconds: 80), () {
      if (mounted) setState(() {});
    });
  }

  Widget _buildPeerAvatar() {
    String initial(String name) {
      final trimmed = name.trim();
      if (trimmed.isEmpty) return '?';
      return trimmed.characters.first.toUpperCase();
    }

    final avatar = (_peerAvatarUrlLocal ?? widget.peerAvatarUrl ?? '').trim();
    final name =
        _peerNameLocal ?? widget.peerName ?? (_chatData['groupName'] ?? '');
    final localThumb = (_peerAvatarThumbPath ?? '').trim();
    if (localThumb.isNotEmpty && File(localThumb).existsSync()) {
      return CircleAvatar(
        radius: 18,
        backgroundImage: FileImage(File(localThumb)),
      );
    }
    if (avatar.isNotEmpty) {
      return CircleAvatar(radius: 18, backgroundImage: NetworkImage(avatar));
    }
    return CircleAvatar(
      radius: 18,
      backgroundColor: Colors.white.withValues(alpha: 0.12),
      child: Text(
        initial(name.toString()),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Future<void> _refreshPeerAvatarThumb() async {
    final avatar = (_peerAvatarUrlLocal ?? widget.peerAvatarUrl ?? '').trim();
    if (avatar.isEmpty || !avatar.startsWith('http')) {
      if (!mounted) return;
      if (_peerAvatarThumbPath != null || _peerAvatarThumbUrl.isNotEmpty) {
        setState(() {
          _peerAvatarThumbPath = null;
          _peerAvatarThumbUrl = '';
        });
      }
      return;
    }

    final requestedUrl = avatar;
    _peerAvatarThumbUrl = requestedUrl;
    final localPath = await AvatarThumbnailCacheService.instance
        .getOrCreateThumbnailPath(
          imageUrl: requestedUrl,
          targetSize: 84,
          quality: 64,
        );

    if (!mounted) return;
    final currentAvatar = (_peerAvatarUrlLocal ?? widget.peerAvatarUrl ?? '')
        .trim();
    if (currentAvatar != requestedUrl) return;
    if (_peerAvatarThumbPath == localPath) return;
    setState(() {
      _peerAvatarThumbPath = localPath;
    });
  }

  Future<void> _fetchAndCacheUserName(String uid) async {
    if (uid.isEmpty ||
        _userNameCache.containsKey(uid) ||
        _pendingUserNameFetches.contains(uid)) {
      return;
    }
    _pendingUserNameFetches.add(uid);
    try {
      final name = await _viewModel.fetchUserDisplayName(uid);
      if (name.isNotEmpty && !_userNameCache.containsKey(uid)) {
        _userNameCache[uid] = name;
        _scheduleUserNameRefresh();
      }
    } catch (_) {}
    _pendingUserNameFetches.remove(uid);
  }

  void _beginReplyFromDoc(String id, Map<String, dynamic> d) {
    final isMeSrc = (d['senderId'] == _myUid);
    final isDeleted = (d['isDeleted'] ?? false) == true;
    final txtSrc = isDeleted
        ? 'Pesan ini telah dihapus'
        : (d['text'] ?? '').toString();
    setState(() {
      _replyTarget = Msg(
        id: id,
        text: txtSrc,
        isMe: isMeSrc,
        time: TimeOfDay.now(),
      );
      _flashReply = true;
    });
    Future.delayed(const Duration(milliseconds: 220), () {
      if (mounted) setState(() => _flashReply = false);
    });
  }

  void _cancelReply() {
    if (!mounted) return;
    setState(() => _replyTarget = null);
  }

  Future<void> _saveImageForMessage({
    String? localPath,
    String? imageUrl,
  }) async {
    try {
      if (localPath != null && localPath.isNotEmpty) {
        // Simpan langsung dari file lokal
        await Gal.putImage(localPath);
      } else if (imageUrl != null && imageUrl.isNotEmpty) {
        // Unduh bytes lalu simpan ke file temp, kemudian masukkan ke galeri
        final uri = Uri.parse(imageUrl);
        final resp = await http.get(uri);
        if (resp.statusCode != 200) {
          throw 'HTTP ${resp.statusCode}';
        }
        final dir = await getTemporaryDirectory();
        final file = File(
          '${dir.path}/img_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        await file.writeAsBytes(resp.bodyBytes);
        await Gal.putImage(file.path);
      } else {
        throw 'Tidak ada sumber gambar';
      }
      if (!mounted) return;
      showGlassSnackBar(
        context,
        message: 'Gambar disimpan ke galeri',
        tone: GlassSnackTone.success,
      );
    } catch (e) {
      if (!mounted) return;
      showGlassSnackBar(
        context,
        message: 'Gagal menyimpan gambar: $e',
        tone: GlassSnackTone.error,
      );
    }
  }

  Future<Directory?> _resolveDownloadDirectory() async {
    try {
      if (Platform.isAndroid) {
        final downloads = await getExternalStorageDirectories(
          type: StorageDirectory.downloads,
        );
        if (downloads != null && downloads.isNotEmpty) {
          return downloads.first;
        }
        return await getExternalStorageDirectory();
      }
      if (Platform.isIOS) {
        return await getApplicationDocumentsDirectory();
      }
      final desktop = await getDownloadsDirectory();
      if (desktop != null) return desktop;
    } catch (_) {}
    return await getTemporaryDirectory();
  }

  Future<void> _downloadFileForMessage({
    required String msgId,
    required String url,
    String? fileName,
  }) async {
    try {
      final uri = Uri.parse(url);
      final response = await http.get(uri);
      if (response.statusCode != 200) {
        throw 'HTTP ${response.statusCode}';
      }
      final targetDir = await _resolveDownloadDirectory();
      if (targetDir == null) {
        throw 'Tidak menemukan lokasi penyimpanan';
      }
      final sanitizedName = (fileName?.trim().isNotEmpty ?? false)
          ? fileName!.trim()
          : (p.basename(uri.path).isNotEmpty
                ? p.basename(uri.path)
                : 'file_${DateTime.now().millisecondsSinceEpoch}');
      final filePath = p.join(targetDir.path, sanitizedName);
      final file = File(filePath);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(response.bodyBytes);
      if (!mounted) return;
      setState(() {
        _downloadedFiles[msgId] = filePath;
      });
      showGlassSnackBar(
        context,
        message: 'File disimpan di ${file.parent.path}',
        tone: GlassSnackTone.success,
      );
    } catch (e) {
      if (!mounted) return;
      showGlassSnackBar(
        context,
        message: 'Gagal mengunduh file: $e',
        tone: GlassSnackTone.error,
      );
    }
  }

  String get _myUid => _viewModel.currentUserUid;

  final TextEditingController _textCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  final ImagePicker _picker = ImagePicker();
  final Map<String, String> _localMediaPreview = {};
  String get _localMediaPrefsKey =>
      'chatLocalMedia_${widget.chatId ?? 'dummy'}';
  String get _pendingTextPrefsKey =>
      'chatLocalPendingText_${widget.chatId ?? 'dummy'}';
  final Map<String, String> _downloadedFiles = {};

  void _syncSessionPreviewCache() {
    final cid = widget.chatId;
    if (cid == null) return;
    _localMediaSessionCache[cid] = Map<String, String>.from(_localMediaPreview);
  }

  Map<String, _LocalPendingTextMessage> _clonePendingTextMap(
    Map<String, _LocalPendingTextMessage> source,
  ) {
    final cloned = <String, _LocalPendingTextMessage>{};
    for (final entry in source.entries) {
      final message = entry.value;
      final copied = _LocalPendingTextMessage(
        localId: message.localId,
        text: message.text,
        createdAt: message.createdAt,
        replyToId: message.replyToId,
        replyToText: message.replyToText,
        replyToFromMe: message.replyToFromMe,
      );
      copied.serverMessageId = message.serverMessageId;
      cloned[entry.key] = copied;
    }
    return cloned;
  }

  void _syncPendingTextSessionCache() {
    final cid = widget.chatId;
    if (cid == null) return;
    _localPendingTextSessionCache[cid] = _clonePendingTextMap(
      _pendingTextMessages,
    );
  }

  Future<void> _persistPendingTextMessages() async {
    if (widget.chatId == null) return;
    _syncPendingTextSessionCache();
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_pendingTextMessages.isEmpty) {
        await prefs.remove(_pendingTextPrefsKey);
        return;
      }
      final payload = _pendingTextMessages.values
          .map(
            (pending) => <String, dynamic>{
              'localId': pending.localId,
              'text': pending.text,
              'createdAt': pending.createdAt.toIso8601String(),
              if (pending.replyToId != null) 'replyToId': pending.replyToId,
              if (pending.replyToText != null)
                'replyToText': pending.replyToText,
              if (pending.replyToFromMe != null)
                'replyToFromMe': pending.replyToFromMe,
              if (pending.serverMessageId != null)
                'serverMessageId': pending.serverMessageId,
            },
          )
          .toList(growable: false);
      await prefs.setString(_pendingTextPrefsKey, json.encode(payload));
    } catch (_) {}
  }

  // upload state: uploading flags, progress (0..1), failed set
  final Map<String, bool> _uploading = {};
  final Map<String, double> _uploadProgress = {};
  final Map<String, double> _lastUiUploadProgress = {};
  final Map<String, DateTime> _lastUiUploadProgressAt = {};
  final Map<String, _LocalPendingTextMessage> _pendingTextMessages = {};
  final Set<String> _animateBubbleIds = <String>{};
  final Set<String> _receiveSoundKnownMessageIds = <String>{};
  bool _receiveSoundSeeded = false;
  DateTime _lastSendSoundAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastReceiveSoundAt = DateTime.fromMillisecondsSinceEpoch(0);
  final AudioPlayer _sendSoundPlayer = AudioPlayer();
  final AudioPlayer _receiveSoundPlayer = AudioPlayer();
  bool _preferAssetSounds = true;
  final Set<String> _uploadFailed = {};
  final Set<String> _deliveredQueue = <String>{};
  final Set<String> _deliveredPending = <String>{};
  Timer? _deliveredFlushTimer;
  bool _deliveredFlushRunning = false;

  final List<Msg> _messages = <Msg>[
    Msg(
      id: 'd1',
      text: 'Halo! 👋',
      isMe: false,
      time: const TimeOfDay(hour: 9, minute: 12),
      delivered: true,
      readBy: const [],
    ),
    Msg(
      id: 'd2',
      text: 'Selamat datang di chat.',
      isMe: false,
      time: const TimeOfDay(hour: 9, minute: 12),
      delivered: true,
      readBy: const [],
    ),
  ];

  // Guard to prevent multiple forward sheets stacking
  bool _forwardSheetOpen = false;

  bool _markedReadOnce = false;
  String? _peerUid;
  // locally cached peer profile values (resolved from Firestore)
  String? _peerNameLocal;
  String? _peerAvatarUrlLocal;
  Msg? _replyTarget;
  bool _flashReply = false;

  StreamSubscription? _connSub;

  StreamSubscription<ChatPageUserProfile>? _peerPresenceSub;
  StreamSubscription<ChatPageUserProfile>? _peerProfileSub;
  String _peerPresenceText = 'online';

  Timer? _presenceTimer;
  // Typing indicator state
  Timer? _typingStopTimer;
  DateTime? _lastTypingSentAt;
  bool _typingSentActive = false;
  StreamSubscription<Map<String, DateTime?>>? _typingSub;
  String? _typingText; // header override when someone is typing
  Stream<List<ChatPageMessageRecord>>? _messagesStream;

  Map<String, dynamic> _chatData = {};
  List<dynamic> get _members => (_chatData['members'] as List<dynamic>?) ?? [];

  Future<String?> _getPeerUid(String chatId) async {
    try {
      final p = await _viewModel.getPeerUid(chatId: chatId, myUid: _myUid);
      if (p == null || p.isEmpty) return null;
      _peerUid = p;
      return p;
    } catch (_) {
      return null;
    }
  }

  Future<void> _markRead() async {
    if (widget.chatId == null || _myUid.isEmpty) return;
    try {
      ChatListRepositoryImpl.saveLocalReadTime(widget.chatId!);
      await _viewModel.markRead(chatId: widget.chatId!, myUid: _myUid);
    } catch (_) {}
  }

  void _queueDeliveredUpdate(String messageId) {
    if (widget.chatId == null) return;
    final id = messageId.trim();
    if (id.isEmpty || _deliveredPending.contains(id)) return;
    _deliveredPending.add(id);
    _deliveredQueue.add(id);
    _deliveredFlushTimer?.cancel();
    _deliveredFlushTimer = Timer(
      const Duration(milliseconds: 220),
      _flushDeliveredUpdates,
    );
  }

  Future<void> _flushDeliveredUpdates() async {
    if (_deliveredFlushRunning || widget.chatId == null) return;
    if (_deliveredQueue.isEmpty) return;
    _deliveredFlushRunning = true;
    final ids = List<String>.from(_deliveredQueue);
    _deliveredQueue.clear();
    try {
      await _viewModel.markMessagesDelivered(
        chatId: widget.chatId!,
        messageIds: ids,
      );
    } catch (_) {
      for (final id in ids) {
        _deliveredPending.remove(id);
      }
      _deliveredQueue.addAll(ids);
      _deliveredFlushTimer?.cancel();
      _deliveredFlushTimer = Timer(
        const Duration(milliseconds: 500),
        _flushDeliveredUpdates,
      );
    } finally {
      _deliveredFlushRunning = false;
    }
  }

  Set<String> _matchedPendingTextLocalIds(List<ChatPageMessageRecord> docs) {
    if (_pendingTextMessages.isEmpty) return const <String>{};
    final serverIds = docs.map((e) => e.id).toSet();
    final serverClientIds = docs
        .map((e) => (e.data['clientMessageId'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toSet();
    final matchedLocalIds = <String>{};
    for (final entry in _pendingTextMessages.entries) {
      final localId = entry.key;
      final pending = entry.value;
      final matchedByClientId = serverClientIds.contains(localId);
      final matchedByServerId =
          pending.serverMessageId != null &&
          serverIds.contains(pending.serverMessageId);
      if (matchedByClientId || matchedByServerId) {
        matchedLocalIds.add(localId);
      }
    }
    return matchedLocalIds;
  }

  void _schedulePendingTextCleanup(Set<String> localIds) {
    if (localIds.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        for (final id in localIds) {
          _pendingTextMessages.remove(id);
          _animateBubbleIds.remove(id);
        }
      });
      unawaited(_persistPendingTextMessages());
    });
  }

  void _enqueueBubbleAnimation(String messageId) {
    if (messageId.isEmpty) return;
    _animateBubbleIds.add(messageId);
    Future<void>.delayed(const Duration(milliseconds: 280), () {
      if (!mounted) return;
      if (_animateBubbleIds.remove(messageId)) {
        setState(() {});
      }
    });
  }

  Future<void> _playSendSound() async {
    final now = DateTime.now();
    if (now.difference(_lastSendSoundAt).inMilliseconds < 80) return;
    _lastSendSoundAt = now;
    if (_preferAssetSounds) {
      try {
        await _sendSoundPlayer.stop();
        await _sendSoundPlayer.play(AssetSource(_sendSoundAsset));
        return;
      } catch (_) {
        _preferAssetSounds = false;
      }
    }
    try {
      await SystemSound.play(SystemSoundType.click);
    } catch (_) {}
  }

  Future<void> _playReceiveSound() async {
    final now = DateTime.now();
    if (now.difference(_lastReceiveSoundAt).inMilliseconds < 120) return;
    _lastReceiveSoundAt = now;
    if (_preferAssetSounds) {
      try {
        await _receiveSoundPlayer.stop();
        await _receiveSoundPlayer.play(AssetSource(_receiveSoundAsset));
        return;
      } catch (_) {
        _preferAssetSounds = false;
      }
    }
    try {
      await SystemSound.play(SystemSoundType.alert);
    } catch (_) {}
  }

  void _handleIncomingReceiveSound(List<ChatPageMessageRecord> docs) {
    if (docs.isEmpty) return;
    final incomingIds = docs
        .where((record) => (record.data['senderId'] as String? ?? '') != _myUid)
        .map((record) => record.id)
        .toList(growable: false);
    if (!_receiveSoundSeeded) {
      _receiveSoundKnownMessageIds.addAll(incomingIds);
      _receiveSoundSeeded = true;
      return;
    }
    var hasNewIncoming = false;
    for (final id in incomingIds) {
      if (_receiveSoundKnownMessageIds.add(id)) {
        hasNewIncoming = true;
      }
    }
    if (hasNewIncoming) {
      unawaited(_playReceiveSound());
    }
  }

  void _updateUploadProgressUi(String messageId, double progress) {
    final normalized = progress.clamp(0.0, 1.0);
    final previous = _lastUiUploadProgress[messageId] ?? 0.0;
    final now = DateTime.now();
    final lastAt =
        _lastUiUploadProgressAt[messageId] ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final shouldNotify =
        normalized >= 1.0 ||
        (normalized - previous) >= 0.03 ||
        now.difference(lastAt).inMilliseconds >= 250;

    _uploadProgress[messageId] = normalized;
    if (!shouldNotify) return;
    _lastUiUploadProgress[messageId] = normalized;
    _lastUiUploadProgressAt[messageId] = now;
    if (mounted) setState(() {});
  }

  void _clearUploadProgressTracking(String messageId) {
    _lastUiUploadProgress.remove(messageId);
    _lastUiUploadProgressAt.remove(messageId);
  }

  @override
  void initState() {
    super.initState();
    _sendSoundPlayer.audioCache = AudioCache(prefix: '');
    _receiveSoundPlayer.audioCache = AudioCache(prefix: '');
    _sendSoundPlayer.setReleaseMode(ReleaseMode.stop);
    _receiveSoundPlayer.setReleaseMode(ReleaseMode.stop);
    _viewModelTag = 'chat-page-${identityHashCode(this)}';
    _viewModel = Get.put(
      widget.viewModel ??
          ChatPageViewModel(
            repository: widget.repository ?? ChatPageRepositoryImpl(),
          ),
      tag: _viewModelTag,
    );
    _setActiveChat(widget.chatId);
    // Ambil cache session agar preview media langsung ada tanpa menunggu I/O.
    final cached = widget.chatId != null
        ? _localMediaSessionCache[widget.chatId!]
        : null;
    if (cached != null && cached.isNotEmpty) {
      _localMediaPreview.addAll(cached);
    }
    final pendingCached = widget.chatId != null
        ? _localPendingTextSessionCache[widget.chatId!]
        : null;
    if (pendingCached != null && pendingCached.isNotEmpty) {
      _pendingTextMessages.addAll(_clonePendingTextMap(pendingCached));
    }
    if (widget.chatId != null && _myUid.isNotEmpty) {
      _viewModel.fetchChatData(widget.chatId!).then((data) {
        if (mounted && data.isNotEmpty) {
          setState(() {
            _chatData = data;
          });
        }
      });

      _messagesStream = _viewModel.watchMessages(
        chatId: widget.chatId!,
        limit: 100,
      );

      if (!widget.isGroup) {
        // resolve peer uid and load their profile (name + avatar)
        _getPeerUid(widget.chatId!);
        _loadPeerProfile();
        // Listen presence peer
        _listenPeerPresence();
      }
      // Listen typing state for this chat
      _listenTyping();

      // Monitor konektivitas perangkat sendiri
      _connSub = Connectivity().onConnectivityChanged.listen((_) {});

      // Heartbeat presence saya
      _startPresenceHeartbeat();
      // Start typing change listener
      _textCtrl.addListener(_onTextChanged);
      _rehydrateLocalPreviews();
      _rehydratePendingTextMessages();
    }
    unawaited(_refreshPeerAvatarThumb());
  }

  @override
  void didUpdateWidget(covariant ChatPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chatId != widget.chatId) {
      _setActiveChat(widget.chatId);
      _receiveSoundKnownMessageIds.clear();
      _receiveSoundSeeded = false;
      _peerAvatarThumbPath = null;
      _peerAvatarThumbUrl = '';
      if (widget.chatId != null) {
        _messagesStream = _viewModel.watchMessages(
          chatId: widget.chatId!,
          limit: 100,
        );
      } else {
        _messagesStream = null;
      }
    }
    if (oldWidget.peerAvatarUrl != widget.peerAvatarUrl ||
        oldWidget.chatId != widget.chatId) {
      unawaited(_refreshPeerAvatarThumb());
    }
  }

  Future<void> _loadPeerProfile() async {
    if (widget.chatId == null) return;
    try {
      _peerUid ??= await _getPeerUid(widget.chatId!);
      final peer = _peerUid;
      if (peer == null || peer.isEmpty) return;
      _listenPeerProfile(peer);
      final profile = await _viewModel.fetchUserProfile(peer);
      final resolvedName = profile.name.isNotEmpty
          ? profile.name
          : (widget.peerName ?? '');
      final resolvedAvatar = profile.avatarUrl;
      if (!mounted) return;
      setState(() {
        if (resolvedName.isNotEmpty) {
          _peerNameLocal = resolvedName;
        }
        _peerAvatarUrlLocal = resolvedAvatar;
      });
      unawaited(_refreshPeerAvatarThumb());
    } catch (_) {}
  }

  void _listenPeerProfile(String peerUid) {
    _peerProfileSub?.cancel();
    _peerProfileSub = _viewModel.watchUserProfile(peerUid).listen((profile) {
      final name = profile.name;
      final avatar = profile.avatarUrl;
      if (!mounted) return;
      final nextName = name.isNotEmpty ? name : _peerNameLocal;
      if (_peerNameLocal == nextName && _peerAvatarUrlLocal == avatar) {
        return;
      }
      setState(() {
        _peerNameLocal = nextName;
        _peerAvatarUrlLocal = avatar;
      });
      unawaited(_refreshPeerAvatarThumb());
    });
  }

  @override
  void dispose() {
    if (Get.isRegistered<ChatPageViewModel>(tag: _viewModelTag)) {
      Get.delete<ChatPageViewModel>(tag: _viewModelTag, force: true);
    }
    _setActiveChat(null);
    _textCtrl.removeListener(_onTextChanged);
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    _connSub?.cancel();
    _peerPresenceSub?.cancel();
    _peerProfileSub?.cancel();
    _presenceTimer?.cancel();
    _typingSub?.cancel();
    _typingStopTimer?.cancel();
    _userNameRefreshTimer?.cancel();
    _deliveredFlushTimer?.cancel();
    _sendSoundPlayer.dispose();
    _receiveSoundPlayer.dispose();
    // clear typing flag on exit
    _setTyping(active: false);
    // persist local media cache
    () async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final jsonStr = json.encode(_localMediaPreview);
        await prefs.setString(_localMediaPrefsKey, jsonStr);
        _syncSessionPreviewCache();
        await _persistPendingTextMessages();
      } catch (_) {}
    }();
    // set offline lastSeen
    if (widget.chatId != null) {
      final myUid = _myUid;
      if (myUid.isNotEmpty) {
        _viewModel.setPresence(uid: myUid, online: false);
      }
    }
    super.dispose();
  }

  Future<void> _send() async {
    final txt = _textCtrl.text.trim();
    if (txt.isEmpty) return;

    final replyTarget = _replyTarget;
    _textCtrl.clear();
    // stop typing when sending
    _setTyping(active: false);

    if (widget.chatId == null) {
      // Fallback: local dummy mode
      final localId = 'local_${DateTime.now().millisecondsSinceEpoch}';
      setState(() {
        _messages.add(
          Msg(id: localId, text: txt, isMe: true, time: TimeOfDay.now()),
        );
        _enqueueBubbleAnimation(localId);
      });
      unawaited(_playSendSound());
    } else {
      final localId = 'local_text_${DateTime.now().microsecondsSinceEpoch}';
      final now = DateTime.now();
      setState(() {
        _replyTarget = null;
        _pendingTextMessages[localId] = _LocalPendingTextMessage(
          localId: localId,
          text: txt,
          createdAt: now,
          replyToId: replyTarget?.id,
          replyToText: replyTarget?.text,
          replyToFromMe: replyTarget?.isMe,
        );
        _enqueueBubbleAnimation(localId);
      });
      ChatPageRepositoryImpl.cacheLocalChatListPreview(
        chatId: widget.chatId!,
        lastMessage: txt,
        lastSenderId: _myUid,
        lastMessageAt: now,
      );
      unawaited(_persistPendingTextMessages());
      unawaited(_playSendSound());
      try {
        final chatId = widget.chatId!;
        final result = await _viewModel.sendTextMessage(
          chatId: chatId,
          myUid: _myUid,
          text: txt,
          isGroup: widget.isGroup,
          memberIds: _members,
          peerUid:
              _peerUid ?? (widget.isGroup ? null : await _getPeerUid(chatId)),
          clientMessageId: localId,
          replyToId: replyTarget?.id,
          replyToText: replyTarget?.text,
          replyToFromMe: replyTarget?.isMe,
        );
        if (result.resolvedPeerUid != null &&
            result.resolvedPeerUid!.isNotEmpty) {
          _peerUid = result.resolvedPeerUid;
        }
        final pending = _pendingTextMessages[localId];
        if (pending != null && result.messageId != null) {
          pending.serverMessageId = result.messageId;
          unawaited(_persistPendingTextMessages());
        }
      } catch (e) {
        _pendingTextMessages.remove(localId);
        _animateBubbleIds.remove(localId);
        unawaited(_persistPendingTextMessages());
        if (mounted) {
          setState(() {
            _replyTarget ??= replyTarget;
          });
          showGlassSnackBar(
            context,
            message: 'Gagal kirim: $e',
            tone: GlassSnackTone.error,
          );
        }
      }
    }
  }

  // --- Typing indicator helpers ---
  void _onTextChanged() {
    if (widget.chatId == null || _myUid.isEmpty) return;
    final hasText = _textCtrl.text.trim().isNotEmpty;
    _typingStopTimer?.cancel();
    if (hasText) {
      final now = DateTime.now();
      if (!_typingSentActive ||
          _lastTypingSentAt == null ||
          now.difference(_lastTypingSentAt!).inSeconds >= 3) {
        _setTyping(active: true);
        _typingSentActive = true;
        _lastTypingSentAt = now;
      }
      // Auto-clear after inactivity
      _typingStopTimer = Timer(const Duration(seconds: 3), () {
        _setTyping(active: false);
        _typingSentActive = false;
      });
    } else {
      _setTyping(active: false);
      _typingSentActive = false;
    }
  }

  Future<void> _setTyping({required bool active}) async {
    if (widget.chatId == null || _myUid.isEmpty) return;
    try {
      await _viewModel.setTyping(
        chatId: widget.chatId!,
        myUid: _myUid,
        active: active,
      );
    } catch (_) {}
  }

  void _listenTyping() {
    if (widget.chatId == null) return;
    _typingSub?.cancel();
    _typingSub = _viewModel.watchTyping(widget.chatId!).listen((
      typingMap,
    ) async {
      final now = DateTime.now();
      final activeUids = <String>[];
      typingMap.forEach((uid, val) {
        if (uid == _myUid) return;
        if (val == null) {
          activeUids.add(uid);
          return;
        }
        if (now.difference(val).inSeconds <= 6) {
          activeUids.add(uid);
        }
      });

      String? text;
      if (activeUids.isNotEmpty) {
        if (widget.isGroup) {
          // Try to resolve names for first two users
          final names = <String>[];
          for (final uid in activeUids.take(2)) {
            final cached = _userNameCache[uid];
            if (cached == null) {
              // fetch async; subsequent rebuild will show name
              _fetchAndCacheUserName(uid);
            }
            names.add(cached ?? 'Seseorang');
          }
          if (activeUids.length == 1) {
            text = '${names.first} sedang mengetik…';
          } else if (activeUids.length == 2) {
            text = '${names[0]}, ${names[1]} mengetik…';
          } else {
            text =
                '${names[0]}, ${names[1]} dan ${activeUids.length - 2} lainnya mengetik…';
          }
        } else {
          text = 'mengetik…';
        }
      }

      if (mounted && _typingText != text) {
        setState(() {
          _typingText = text;
        });
      }
    });
  }

  void _startPresenceHeartbeat() {
    // Simpan status online & lastSeen ke Firestore users/{uid}
    if (_myUid.isEmpty) return;
    _presenceTimer?.cancel();
    // initial set
    _viewModel.setPresence(uid: _myUid, online: true);

    _presenceTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      _viewModel.setPresence(uid: _myUid, online: true);
    });
  }

  void _listenPeerPresence() async {
    if (widget.chatId == null) return;
    // pastikan peer uid
    _peerUid ??= await _getPeerUid(widget.chatId!);
    final peer = _peerUid;
    if (peer == null || peer.isEmpty) return;

    _peerPresenceSub?.cancel();
    _peerPresenceSub = _viewModel.watchUserProfile(peer).listen((profile) {
      final online = profile.online;
      if (online) {
        if (mounted && _peerPresenceText != 'online') {
          setState(() => _peerPresenceText = 'online');
        }
      } else {
        final ts = profile.lastSeen;
        String last = 'offline';
        if (ts != null) {
          final dt = ts;
          final hh = dt.hour.toString().padLeft(2, '0');
          final mm = dt.minute.toString().padLeft(2, '0');
          last = 'terakhir online $hh:$mm';
        }
        if (mounted && _peerPresenceText != last) {
          setState(() => _peerPresenceText = last);
        }
      }
    });
  }

  Future<void> _openPeerProfile() async {
    if (widget.chatId == null) return;

    // Jika grup, buka GroupProfilePage
    if (widget.isGroup) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GroupProfilePage(chatId: widget.chatId!),
        ),
      );
      return;
    }

    // DM: pastikan kita punya peer uid lalu buka UserProfilePage
    _peerUid ??= await _getPeerUid(widget.chatId!);
    final peer = _peerUid;
    if (!mounted || peer == null || peer.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => UserProfilePage(peerUid: peer)),
    );
  }

  Future<void> _openStarredMessages() async {
    if (widget.chatId == null) return;
    // Pastikan peer uid tersedia (untuk read receipt / judul opsional)
    _peerUid ??= await _getPeerUid(widget.chatId!);
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StarredMessagesPage(
          chatId: widget.chatId,
          peerUid: _peerUid,
          peerName: _peerNameLocal ?? widget.peerName,
        ),
      ),
    );
  }

  Future<void> _openAttachSheet() async {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(
                        Icons.photo_camera,
                        color: Colors.white,
                      ),
                      title: const Text(
                        'Kamera',
                        style: TextStyle(color: Colors.white),
                      ),
                      onTap: () async {
                        Navigator.pop(context);
                        await _pickFromCamera();
                      },
                    ),
                    ListTile(
                      leading: const Icon(
                        Icons.photo_library,
                        color: Colors.white,
                      ),
                      title: const Text(
                        'Media',
                        style: TextStyle(color: Colors.white),
                      ),
                      onTap: () async {
                        Navigator.pop(context);
                        await _pickFromGallery();
                      },
                    ),
                    ListTile(
                      leading: const Icon(
                        Icons.insert_drive_file,
                        color: Colors.white,
                      ),
                      title: const Text(
                        'File',
                        style: TextStyle(color: Colors.white),
                      ),
                      onTap: () async {
                        Navigator.pop(context);
                        await _pickAndSendFile();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickFromCamera() async {
    try {
      final x = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
      );
      if (x == null) return;
      await _sendImageFromXFile(x);
    } catch (e) {
      if (!mounted) return;
      showGlassSnackBar(
        context,
        message: 'Gagal ambil kamera: $e',
        tone: GlassSnackTone.error,
      );
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final x = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );
      if (x == null) return;
      await _sendImageFromXFile(x);
    } catch (e) {
      if (!mounted) return;
      showGlassSnackBar(
        context,
        message: 'Gagal ambil media: $e',
        tone: GlassSnackTone.error,
      );
    }
  }

  Future<void> _pickAndSendFile() async {
    try {
      final res = await FilePicker.platform.pickFiles(withData: false);
      if (res == null || res.files.isEmpty) return;
      final file = res.files.first;
      if (file.path == null) return;
      final path = file.path!;
      final name = file.name;
      final size = file.size;
      // create placeholder and upload similar to image
      if (widget.chatId == null) {
        setState(() {
          _messages.add(
            Msg(
              id: 'local_${DateTime.now().millisecondsSinceEpoch}',
              text: name,
              isMe: true,
              time: TimeOfDay.now(),
              imageUrl: null,
              localPath: path,
            ),
          );
        });
        unawaited(_playSendSound());
        return;
      }

      final chatId = widget.chatId!;
      final created = await _viewModel.createFilePlaceholder(
        chatId: chatId,
        myUid: _myUid,
        isGroup: widget.isGroup,
        memberIds: _members,
        fileName: name,
        fileSize: size,
        peerUid: _peerUid,
      );
      if (created.resolvedPeerUid != null &&
          created.resolvedPeerUid!.isNotEmpty) {
        _peerUid = created.resolvedPeerUid;
      }
      unawaited(_playSendSound());

      // save local preview
      _localMediaPreview[created.messageId] = path;
      _syncSessionPreviewCache();
      try {
        final prefs = await SharedPreferences.getInstance();
        final jsonStr = json.encode(_localMediaPreview);
        await prefs.setString(_localMediaPrefsKey, jsonStr);
      } catch (_) {}

      _uploading[created.messageId] = true;
      _uploadProgress[created.messageId] = 0.0;
      _lastUiUploadProgress[created.messageId] = 0.0;
      _lastUiUploadProgressAt[created.messageId] = DateTime.now();
      _uploadFailed.remove(created.messageId);
      if (mounted) setState(() {});

      try {
        final fileUrl = await _viewModel.uploadChatFile(
          chatId: chatId,
          messageId: created.messageId,
          filePath: path,
          fileName: name,
          onProgress: (progress) {
            _updateUploadProgressUi(created.messageId, progress);
          },
        );
        await _viewModel.updateMessageFields(
          chatId: chatId,
          messageId: created.messageId,
          data: {'fileUrl': fileUrl},
        );
        _uploading.remove(created.messageId);
        _uploadProgress.remove(created.messageId);
        _clearUploadProgressTracking(created.messageId);
        _uploadFailed.remove(created.messageId);
        _syncSessionPreviewCache();
        if (mounted) setState(() {});
      } catch (_) {
        _uploading.remove(created.messageId);
        _uploadProgress.remove(created.messageId);
        _clearUploadProgressTracking(created.messageId);
        _uploadFailed.add(created.messageId);
        if (mounted) setState(() {});
        rethrow;
      }
    } catch (e) {
      if (!mounted) return;
      showGlassSnackBar(
        context,
        message: 'Gagal kirim file: $e',
        tone: GlassSnackTone.error,
      );
    }
  }

  Future<void> _openFile(Msg msg) async {
    final local = msg.localPath;
    if (local != null && local.isNotEmpty) {
      final file = File(local);
      if (await file.exists()) {
        try {
          final result = await OpenFilex.open(file.path);
          if (result.type != ResultType.done && mounted) {
            final fallbackMessage = result.message.isNotEmpty
                ? result.message
                : 'File tersimpan di ${file.parent.path}';
            showGlassSnackBar(
              context,
              message: fallbackMessage,
              tone: GlassSnackTone.info,
            );
          }
          return;
        } on MissingPluginException {
          if (!mounted) return;
          showGlassSnackBar(
            context,
            message:
                'Fitur pembuka file belum aktif di build ini. Coba tutup & buka ulang aplikasi (atau reinstall). File ada di ${file.parent.path}',
            tone: GlassSnackTone.error,
          );
          return;
        } catch (e) {
          if (!mounted) return;
          showGlassSnackBar(
            context,
            message: 'Gagal membuka file lokal: $e',
            tone: GlassSnackTone.error,
          );
          return;
        }
      }
    }
    final url = msg.fileUrl;
    if (url == null || url.isEmpty) return;
    try {
      await launchUrl(Uri.parse(url));
    } catch (e) {
      if (!mounted) return;
      showGlassSnackBar(
        context,
        message: 'Gagal membuka file: $e',
        tone: GlassSnackTone.error,
      );
    }
  }

  Future<void> _sendImageFromXFile(XFile xfile) async {
    // Jika belum ada chatId (dummy mode), tampilkan di UI saja
    if (widget.chatId == null) {
      setState(() {
        _messages.add(
          Msg(
            id: 'local_${DateTime.now().millisecondsSinceEpoch}',
            text: 'Foto',
            isMe: true,
            time: TimeOfDay.now(),
            imageUrl: null,
            localPath: xfile.path,
          ),
        );
      });
      unawaited(_playSendSound());
      return;
    }

    final chatId = widget.chatId!;
    final created = await _viewModel.createImagePlaceholder(
      chatId: chatId,
      myUid: _myUid,
      isGroup: widget.isGroup,
      memberIds: _members,
      peerUid: _peerUid,
    );
    if (created.resolvedPeerUid != null &&
        created.resolvedPeerUid!.isNotEmpty) {
      _peerUid = created.resolvedPeerUid;
    }
    unawaited(_playSendSound());

    // create placeholder message immediately so UI shows a bubble
    try {
      // save local preview so bubble shows local file while uploading
      _localMediaPreview[created.messageId] = xfile.path;
      _syncSessionPreviewCache();
      try {
        final prefs = await SharedPreferences.getInstance();
        final jsonStr = json.encode(_localMediaPreview);
        await prefs.setString(_localMediaPrefsKey, jsonStr);
      } catch (_) {}

      // set uploading state
      _uploading[created.messageId] = true;
      _uploadProgress[created.messageId] = 0.0;
      _lastUiUploadProgress[created.messageId] = 0.0;
      _lastUiUploadProgressAt[created.messageId] = DateTime.now();
      _uploadFailed.remove(created.messageId);
      if (mounted) setState(() {});

      // start upload with progress
      final imageUrl = await _viewModel.uploadChatImage(
        chatId: chatId,
        messageId: created.messageId,
        filePath: xfile.path,
        onProgress: (progress) {
          _updateUploadProgressUi(created.messageId, progress);
        },
      );
      await _viewModel.updateMessageFields(
        chatId: chatId,
        messageId: created.messageId,
        data: {'imageUrl': imageUrl},
      );
      final removedPath = _localMediaPreview.remove(created.messageId);
      if (removedPath != null && removedPath.isNotEmpty) {
        try {
          final f = File(removedPath);
          if (await f.exists()) {
            await f.delete();
          }
        } catch (_) {}
        try {
          final prefs = await SharedPreferences.getInstance();
          final jsonStr = json.encode(_localMediaPreview);
          await prefs.setString(_localMediaPrefsKey, jsonStr);
        } catch (_) {}
      }
      _uploading.remove(created.messageId);
      _uploadProgress.remove(created.messageId);
      _clearUploadProgressTracking(created.messageId);
      _uploadFailed.remove(created.messageId);
      _syncSessionPreviewCache();
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      showGlassSnackBar(
        context,
        message: 'Gagal mengirim foto: $e',
        tone: GlassSnackTone.error,
      );
      // ensure state cleaned
      _uploading.remove(created.messageId);
      _uploadProgress.remove(created.messageId);
      _clearUploadProgressTracking(created.messageId);
      _uploadFailed.add(created.messageId);
      if (mounted) setState(() {});
    }
  }

  Future<void> _retryUpload(String msgId) async {
    final localPath = _localMediaPreview[msgId];
    if (localPath == null || widget.chatId == null) return;
    final chatId = widget.chatId!;

    try {
      _uploadFailed.remove(msgId);
      _uploading[msgId] = true;
      _uploadProgress[msgId] = 0.0;
      _lastUiUploadProgress[msgId] = 0.0;
      _lastUiUploadProgressAt[msgId] = DateTime.now();
      if (mounted) setState(() {});

      final imageUrl = await _viewModel.uploadChatImage(
        chatId: chatId,
        messageId: msgId,
        filePath: localPath,
        onProgress: (progress) {
          _updateUploadProgressUi(msgId, progress);
        },
      );
      await _viewModel.updateMessageFields(
        chatId: chatId,
        messageId: msgId,
        data: {'imageUrl': imageUrl},
      );
      final removedPath = _localMediaPreview.remove(msgId);
      if (removedPath != null && removedPath.isNotEmpty) {
        try {
          final f = File(removedPath);
          if (await f.exists()) {
            await f.delete();
          }
        } catch (_) {}
        try {
          final prefs = await SharedPreferences.getInstance();
          final jsonStr = json.encode(_localMediaPreview);
          await prefs.setString(_localMediaPrefsKey, jsonStr);
        } catch (_) {}
      }
      _uploading.remove(msgId);
      _uploadProgress.remove(msgId);
      _clearUploadProgressTracking(msgId);
      _uploadFailed.remove(msgId);
      _syncSessionPreviewCache();
      if (mounted) setState(() {});
    } catch (_) {
      _uploading.remove(msgId);
      _uploadProgress.remove(msgId);
      _clearUploadProgressTracking(msgId);
      _uploadFailed.add(msgId);
      if (mounted) setState(() {});
    }
  }

  Future<void> _rehydrateLocalPreviews() async {
    if (widget.chatId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final mapJson = prefs.getString(_localMediaPrefsKey);
      if (mapJson == null || mapJson.isEmpty) {
        if (_localMediaPreview.isEmpty) return;
        _localMediaPreview.clear();
        _syncSessionPreviewCache();
        if (mounted) setState(() {});
        return;
      }
      final Map<String, dynamic> raw =
          json.decode(mapJson) as Map<String, dynamic>;
      final Map<String, String> cleaned = {};
      for (final entry in raw.entries) {
        final path = entry.value.toString();
        if (path.isEmpty) continue;
        try {
          final file = File(path);
          if (!await file.exists()) {
            continue;
          }
        } catch (_) {
          continue;
        }
        cleaned[entry.key] = path;
      }
      _localMediaPreview
        ..clear()
        ..addAll(cleaned);
      _syncSessionPreviewCache();
      if (cleaned.length != raw.length) {
        try {
          final prefs = await SharedPreferences.getInstance();
          final jsonStr = json.encode(_localMediaPreview);
          await prefs.setString(_localMediaPrefsKey, jsonStr);
        } catch (_) {}
      }
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _rehydratePendingTextMessages() async {
    if (widget.chatId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_pendingTextPrefsKey);
      if (raw == null || raw.isEmpty) {
        if (_pendingTextMessages.isEmpty) return;
        _animateBubbleIds.removeWhere(_pendingTextMessages.containsKey);
        _pendingTextMessages.clear();
        _syncPendingTextSessionCache();
        if (mounted) setState(() {});
        return;
      }
      final decoded = json.decode(raw);
      if (decoded is! List) return;
      final cleaned = <String, _LocalPendingTextMessage>{};
      final now = DateTime.now();
      for (final item in decoded) {
        if (item is! Map) continue;
        final localId = (item['localId'] ?? '').toString();
        final text = (item['text'] ?? '').toString();
        final createdAtRaw = (item['createdAt'] ?? '').toString();
        final createdAt = DateTime.tryParse(createdAtRaw);
        if (localId.isEmpty || text.isEmpty || createdAt == null) continue;
        if (now.difference(createdAt).inDays > 2) continue;
        final pending = _LocalPendingTextMessage(
          localId: localId,
          text: text,
          createdAt: createdAt,
          replyToId: item['replyToId']?.toString(),
          replyToText: item['replyToText']?.toString(),
          replyToFromMe: item['replyToFromMe'] as bool?,
        );
        final serverMessageId = item['serverMessageId']?.toString();
        if (serverMessageId != null && serverMessageId.isNotEmpty) {
          pending.serverMessageId = serverMessageId;
        }
        cleaned[localId] = pending;
      }

      _pendingTextMessages
        ..clear()
        ..addAll(cleaned);
      _syncPendingTextSessionCache();
      if (mounted) setState(() {});

      if (cleaned.length != decoded.length) {
        await _persistPendingTextMessages();
      }
    } catch (_) {}
  }

  Future<void> _showForwardSheet({
    required Map<String, dynamic> msgData,
  }) async {
    if (_forwardSheetOpen) return;
    _forwardSheetOpen = true;
    try {
      final targets = await _viewModel.getForwardTargets(
        myUid: _myUid,
        excludeChatId: widget.chatId,
      );

      if (!mounted) return;
      await showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (_) {
          return ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const ListTile(
                        title: Text(
                          'Teruskan ke…',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Divider(height: 1, color: Colors.white24),
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: targets.length,
                          itemBuilder: (context, i) {
                            final target = targets[i];
                            final peer = target.peerUid;
                            return FutureBuilder<ChatPageUserProfile>(
                              future: peer.isEmpty
                                  ? null
                                  : _viewModel.fetchUserProfile(peer),
                              builder: (context, snap) {
                                final name = snap.data?.name ?? 'Chat';
                                final avatar = snap.data?.avatarUrl;
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundImage:
                                        (avatar != null && avatar.isNotEmpty)
                                        ? NetworkImage(avatar)
                                        : const AssetImage(
                                                'lib/app/assets/images/cvm.png',
                                              )
                                              as ImageProvider,
                                  ),
                                  title: Text(
                                    name,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  onTap: () async {
                                    Navigator.pop(context);
                                    await _forwardToChat(
                                      targetChatId: target.chatId,
                                      original: msgData,
                                    );
                                  },
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    } finally {
      _forwardSheetOpen = false;
    }
  }

  Future<void> _forwardToChat({
    required String targetChatId,
    required Map<String, dynamic> original,
  }) async {
    try {
      final String type = (original['type'] ?? 'text').toString();
      final String text = (original['text'] ?? '').toString();
      final String? imageUrl = original['imageUrl'] as String?;
      await _viewModel.forwardMessage(
        targetChatId: targetChatId,
        myUid: _myUid,
        type: type,
        text: text,
        imageUrl: imageUrl,
      );

      if (!mounted) return;
      showGlassSnackBar(
        context,
        message: 'Pesan diteruskan',
        tone: GlassSnackTone.success,
      );
    } catch (e) {
      if (!mounted) return;
      showGlassSnackBar(
        context,
        message: 'Gagal meneruskan: $e',
        tone: GlassSnackTone.error,
      );
    }
  }

  void _showMessageActions({
    required String msgId,
    required bool isMe,
    required bool isStarred,
    required Map<String, dynamic> rawData,
    String? localPath,
    String? imageUrl,
    String? fileUrl,
    String? fileName,
  }) {
    final hasImage =
        (localPath != null && localPath.isNotEmpty) ||
        (imageUrl != null && imageUrl.isNotEmpty);
    final hasFile = fileUrl != null && fileUrl.isNotEmpty;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if ((rawData['isDeleted'] ?? false) != true)
                    ListTile(
                      leading: const Icon(Icons.forward, color: Colors.white),
                      title: const Text(
                        'Teruskan pesan',
                        style: TextStyle(color: Colors.white),
                      ),
                      onTap: () async {
                        Navigator.pop(context);
                        await _showForwardSheet(msgData: rawData);
                      },
                    ),
                  if (hasImage)
                    ListTile(
                      leading: const Icon(
                        Icons.download_rounded,
                        color: Colors.white,
                      ),
                      title: const Text(
                        'Unduh gambar',
                        style: TextStyle(color: Colors.white),
                      ),
                      onTap: () async {
                        Navigator.pop(context);
                        await _saveImageForMessage(
                          localPath: localPath,
                          imageUrl: imageUrl,
                        );
                      },
                    ),
                  if (hasFile)
                    ListTile(
                      leading: const Icon(
                        Icons.download_for_offline,
                        color: Colors.white,
                      ),
                      title: const Text(
                        'Unduh file',
                        style: TextStyle(color: Colors.white),
                      ),
                      onTap: () async {
                        Navigator.pop(context);
                        await _downloadFileForMessage(
                          msgId: msgId,
                          url: fileUrl,
                          fileName: fileName,
                        );
                      },
                    ),
                  ListTile(
                    leading: Icon(
                      isStarred ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                    ),
                    title: Text(
                      isStarred ? 'Hapus bintang' : 'Bintangi pesan',
                      style: const TextStyle(color: Colors.white),
                    ),
                    onTap: () async {
                      Navigator.pop(context);
                      await _toggleStar(msgId: msgId, value: !isStarred);
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.visibility_off,
                      color: Colors.white,
                    ),
                    title: const Text(
                      'Hapus untuk saya',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () async {
                      Navigator.pop(context);
                      await _deleteForMe(msgId);
                      if (!mounted) return;
                      showGlassSnackBar(
                        context,
                        message: 'Pesan dihapus untuk Anda',
                        tone: GlassSnackTone.success,
                      );
                    },
                  ),
                  if (isMe)
                    ListTile(
                      leading: const Icon(
                        Icons.delete_forever,
                        color: Colors.white,
                      ),
                      title: const Text(
                        'Hapus untuk semua orang',
                        style: TextStyle(color: Colors.white),
                      ),
                      onTap: () async {
                        Navigator.pop(context);
                        await _deleteForAll(msgId);
                        if (!mounted) return;
                        showGlassSnackBar(
                          context,
                          message: 'Pesan dihapus untuk semua',
                          tone: GlassSnackTone.success,
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _deleteForMe(String msgId) async {
    if (widget.chatId == null || _myUid.isEmpty) return;
    await _viewModel.deleteMessageForMe(
      chatId: widget.chatId!,
      messageId: msgId,
      myUid: _myUid,
    );
    // remove any local preview and local file for this message
    try {
      final local = _localMediaPreview.remove(msgId);
      if (local != null && local.isNotEmpty) {
        final f = File(local);
        if (await f.exists()) {
          await f.delete();
        }
      }
      _syncSessionPreviewCache();
      // persist preview map
      try {
        final prefs = await SharedPreferences.getInstance();
        final jsonStr = json.encode(_localMediaPreview);
        await prefs.setString(_localMediaPrefsKey, jsonStr);
      } catch (_) {}
    } catch (_) {}
  }

  Future<void> _deleteForAll(String msgId) async {
    if (widget.chatId == null) return;
    await _viewModel.deleteMessageForAll(
      chatId: widget.chatId!,
      messageId: msgId,
    );

    // Also attempt to remove associated media from Firebase Storage and local cache
    try {
      final data = await _viewModel.fetchMessage(
        chatId: widget.chatId!,
        messageId: msgId,
      );
      final String? imageUrl = data['imageUrl'] as String?;
      // remove storage file if present (we store uploads under chat_media/{chatId}/{msgId}.jpg)
      if (imageUrl != null && imageUrl.isNotEmpty) {
        try {
          await _viewModel.deleteChatImage(
            chatId: widget.chatId!,
            messageId: msgId,
          );
        } catch (_) {
          // ignore storage delete errors
        }
      }

      // remove local preview if any
      final local = _localMediaPreview.remove(msgId);
      if (local != null) {
        try {
          final f = File(local);
          if (await f.exists()) await f.delete();
        } catch (_) {}
      }
      _syncSessionPreviewCache();
      try {
        final prefs = await SharedPreferences.getInstance();
        final jsonStr = json.encode(_localMediaPreview);
        await prefs.setString(_localMediaPrefsKey, jsonStr);
      } catch (_) {}

      // Ensure message document no longer contains imageUrl/localPath so UI won't render it
      try {
        await _viewModel.clearMessageMedia(
          chatId: widget.chatId!,
          messageId: msgId,
        );
      } catch (_) {}
    } catch (_) {}
  }

  Future<void> _toggleStar({required String msgId, required bool value}) async {
    if (widget.chatId == null) return;
    await _viewModel.toggleStar(
      chatId: widget.chatId!,
      messageId: msgId,
      value: value,
      myUid: _myUid,
    );

    if (!mounted) return;
    showGlassSnackBar(
      context,
      message: value ? 'Pesan dibintangi' : 'Bintang dihapus',
      tone: value ? GlassSnackTone.success : GlassSnackTone.info,
      duration: const Duration(seconds: 1),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: RepaintBoundary(child: _ChatBackground())),
        Scaffold(
          extendBodyBehindAppBar: true,
          backgroundColor: Colors.transparent,
          resizeToAvoidBottomInset: true,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: false,
            titleSpacing: 0,
            leadingWidth: 48,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _openPeerProfile,
                borderRadius: BorderRadius.circular(32),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.7),
                            width: 1,
                          ),
                        ),
                        child: _buildPeerAvatar(),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title: prefer groupName for group, else resolved peer name
                            Text(
                              widget.isGroup
                                  ? ((_chatData['groupName'] ??
                                            widget.peerName) ??
                                        'Group')
                                  : (_peerNameLocal ??
                                        widget.peerName ??
                                        'CVM Support'),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            if (widget.isGroup)
                              Text(
                                _typingText ?? '${_members.length} anggota',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white70,
                                ),
                              )
                            else
                              Text(
                                _typingText ?? _peerPresenceText,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white70,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              if (widget.chatId != null)
                IconButton(
                  icon: const Icon(Icons.star_border, color: Colors.white),
                  tooltip: 'Pesan berbintang',
                  onPressed: _openStarredMessages,
                ),
              IconButton(
                icon: const Icon(Icons.person_outline, color: Colors.white),
                tooltip: 'Profil',
                onPressed: () => _openPeerProfile(),
              ),
              IconButton(
                icon: const Icon(Icons.call, color: Colors.white),
                onPressed: () {
                  showGlassSnackBar(
                    context,
                    message: 'Fitur ini akan segera hadir',
                    tone: GlassSnackTone.info,
                  );
                },
              ),
            ],
            flexibleSpace: RepaintBoundary(
              child: Container(
                decoration: BoxDecoration(
                  color: _chatSurfaceSoft,
                  border: Border(
                    bottom: BorderSide(
                      color: const Color.fromRGBO(255, 255, 255, 0.25),
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),
          ),
          body: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => FocusScope.of(context).unfocus(),
            child: SizedBox.expand(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  SafeArea(
                    child: Column(
                      children: [
                        Expanded(
                          child: widget.chatId == null
                              ? ListView.builder(
                                  controller: _scrollCtrl,
                                  physics: const ClampingScrollPhysics(),
                                  keyboardDismissBehavior:
                                      ScrollViewKeyboardDismissBehavior.onDrag,
                                  padding: const EdgeInsets.fromLTRB(
                                    8,
                                    8,
                                    8,
                                    12,
                                  ),
                                  cacheExtent: 360,
                                  itemCount: _messages.length,
                                  itemBuilder: (context, index) {
                                    final m = _messages[index];
                                    final prevIsMe = index > 0
                                        ? _messages[index - 1].isMe
                                        : null;
                                    final nextIsMe =
                                        index < _messages.length - 1
                                        ? _messages[index + 1].isMe
                                        : null;
                                    return Bubble(
                                      key: ValueKey(m.id),
                                      msg: m,
                                      startGroup:
                                          prevIsMe == null ||
                                          prevIsMe != m.isMe,
                                      endGroup:
                                          nextIsMe == null ||
                                          nextIsMe != m.isMe,
                                      peerUid: _peerUid ?? '',
                                      animateIn: _animateBubbleIds.contains(
                                        m.id,
                                      ),
                                    );
                                  },
                                )
                              : StreamBuilder<List<ChatPageMessageRecord>>(
                                  initialData: _viewModel.getCachedMessages(
                                    chatId: widget.chatId!,
                                    limit: 100,
                                  ),
                                  stream: _messagesStream,
                                  builder: (context, snap) {
                                    final docs =
                                        snap.data ??
                                        const <ChatPageMessageRecord>[];
                                    _handleIncomingReceiveSound(docs);
                                    final matchedPendingLocalIds =
                                        _matchedPendingTextLocalIds(docs);
                                    _schedulePendingTextCleanup(
                                      matchedPendingLocalIds,
                                    );
                                    final pendingDocs =
                                        _pendingTextMessages.entries
                                            .where(
                                              (entry) => !matchedPendingLocalIds
                                                  .contains(entry.key),
                                            )
                                            .map((entry) => entry.value)
                                            .toList()
                                          ..sort(
                                            (a, b) => b.createdAt.compareTo(
                                              a.createdAt,
                                            ),
                                          );
                                    final pendingLocalIds = pendingDocs
                                        .map((pending) => pending.localId)
                                        .toSet();
                                    final pendingServerIds = pendingDocs
                                        .map(
                                          (pending) => pending.serverMessageId,
                                        )
                                        .whereType<String>()
                                        .toSet();
                                    final filteredDocs = docs
                                        .where((record) {
                                          final clientId =
                                              (record.data['clientMessageId'] ??
                                                      '')
                                                  .toString();
                                          if (clientId.isNotEmpty &&
                                              pendingLocalIds.contains(
                                                clientId,
                                              )) {
                                            return false;
                                          }
                                          if (pendingServerIds.contains(
                                            record.id,
                                          )) {
                                            return false;
                                          }
                                          return true;
                                        })
                                        .toList(growable: false);
                                    final optimisticRecords = pendingDocs
                                        .map(
                                          (pending) => ChatPageMessageRecord(
                                            id: pending.localId,
                                            data: <String, dynamic>{
                                              'text': pending.text,
                                              'senderId': _myUid,
                                              'type': 'text',
                                              'createdAt': pending.createdAt,
                                              'readBy': <String>[_myUid],
                                              'delivered': false,
                                              'isLocalPending': true,
                                              if (pending.replyToId != null)
                                                'replyToId': pending.replyToId,
                                              if (pending.replyToText != null)
                                                'replyToText':
                                                    pending.replyToText,
                                              if (pending.replyToFromMe != null)
                                                'replyToFromMe':
                                                    pending.replyToFromMe,
                                            },
                                          ),
                                        )
                                        .toList(growable: false);
                                    final combinedDocs =
                                        <ChatPageMessageRecord>[
                                          ...optimisticRecords,
                                          ...filteredDocs,
                                        ];
                                    final memberInfoMap =
                                        (_chatData['memberInfo'] as Map?) ??
                                        const <String, dynamic>{};
                                    if (combinedDocs.isEmpty) {
                                      return const SizedBox();
                                    }

                                    if (!_markedReadOnce && docs.isNotEmpty) {
                                      _markedReadOnce = true;
                                      _markRead();
                                    }

                                    return ListView.builder(
                                      controller: _scrollCtrl,
                                      reverse: true,
                                      physics: const ClampingScrollPhysics(),
                                      keyboardDismissBehavior:
                                          ScrollViewKeyboardDismissBehavior
                                              .onDrag,
                                      padding: const EdgeInsets.fromLTRB(
                                        8,
                                        8,
                                        8,
                                        12,
                                      ),
                                      cacheExtent: 360,
                                      itemCount: combinedDocs.length,
                                      itemBuilder: (context, index) {
                                        // docs already sorted newest -> oldest from query.
                                        final message = combinedDocs[index];
                                        final d = message.data;
                                        final isLocalPending =
                                            (d['isLocalPending'] ?? false) ==
                                            true;
                                        final List<String> deletedFor =
                                            List<String>.from(
                                              (d['deletedFor'] ?? const [])
                                                  as List,
                                            );
                                        if (deletedFor.contains(_myUid)) {
                                          return const SizedBox.shrink();
                                        }

                                        final isDeleted =
                                            (d['isDeleted'] ?? false) == true;
                                        final senderId =
                                            d['senderId'] as String? ?? '';
                                        final isMe = senderId == _myUid;

                                        final senderInfo =
                                            memberInfoMap[senderId] ?? {};
                                        String senderName =
                                            (senderInfo['name'] ?? '')
                                                .toString();
                                        if (senderName.isEmpty) {
                                          senderName =
                                              _userNameCache[senderId] ??
                                              'Unknown';
                                          if (!_userNameCache.containsKey(
                                            senderId,
                                          )) {
                                            _fetchAndCacheUserName(senderId);
                                          }
                                        }

                                        final text = isDeleted
                                            ? 'Pesan ini telah dihapus'
                                            : ((d['text'] ?? '') as String);
                                        final ts = d['createdAt'];
                                        DateTime time;
                                        if (ts is DateTime) {
                                          time = ts;
                                        } else {
                                          time = DateTime.now();
                                        }

                                        final delivered =
                                            (d['delivered'] ?? false) == true;
                                        final List<String> readBy =
                                            List<String>.from(
                                              (d['readBy'] ?? const []) as List,
                                            );

                                        if (!isMe &&
                                            !delivered &&
                                            widget.chatId != null) {
                                          _queueDeliveredUpdate(message.id);
                                        } else if (delivered) {
                                          _deliveredPending.remove(message.id);
                                        }

                                        final prevDocData = index > 0
                                            ? combinedDocs[index - 1].data
                                            : null;
                                        final nextDocData =
                                            index < combinedDocs.length - 1
                                            ? combinedDocs[index + 1].data
                                            : null;
                                        final prevIsMe = prevDocData == null
                                            ? null
                                            : ((prevDocData['senderId']
                                                          as String? ??
                                                      '') ==
                                                  _myUid);
                                        final nextIsMe = nextDocData == null
                                            ? null
                                            : ((nextDocData['senderId']
                                                          as String? ??
                                                      '') ==
                                                  _myUid);
                                        final String? imageUrl =
                                            d['imageUrl'] as String?;
                                        final String? localPreview =
                                            _localMediaPreview[message.id];
                                        final String? downloadedPath =
                                            _downloadedFiles[message.id];

                                        // Show sender name at the start of a sender block in group chats
                                        final prevSenderId =
                                            (prevDocData?['senderId']
                                                as String?) ??
                                            '';
                                        final showSenderHeader =
                                            widget.isGroup &&
                                            (index == 0 ||
                                                prevSenderId != senderId);
                                        final animateIn =
                                            isMe &&
                                            isLocalPending &&
                                            _animateBubbleIds.contains(
                                              message.id,
                                            );

                                        return Column(
                                          crossAxisAlignment: isMe
                                              ? CrossAxisAlignment.end
                                              : CrossAxisAlignment.start,
                                          children: [
                                            if (showSenderHeader && !isMe)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  left: 12,
                                                  right: 12,
                                                  bottom: 4,
                                                ),
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 5,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    gradient:
                                                        const LinearGradient(
                                                          colors: [
                                                            Color.fromRGBO(
                                                              255,
                                                              255,
                                                              255,
                                                              0.26,
                                                            ),
                                                            Color.fromRGBO(
                                                              188,
                                                              224,
                                                              255,
                                                              0.16,
                                                            ),
                                                          ],
                                                          begin:
                                                              Alignment.topLeft,
                                                          end: Alignment
                                                              .bottomRight,
                                                        ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                    border: Border.all(
                                                      color: Colors.white
                                                          .withValues(
                                                            alpha: 0.34,
                                                          ),
                                                    ),
                                                    boxShadow: const [
                                                      BoxShadow(
                                                        color: Color.fromRGBO(
                                                          0,
                                                          0,
                                                          0,
                                                          0.14,
                                                        ),
                                                        blurRadius: 8,
                                                        offset: Offset(0, 2),
                                                      ),
                                                    ],
                                                  ),
                                                  child: Text(
                                                    senderName,
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            Bubble(
                                              key: ValueKey(message.id),
                                              msg: Msg(
                                                replyToId:
                                                    d['replyToId'] as String?,
                                                replyToText:
                                                    d['replyToText'] as String?,
                                                replyToFromMe:
                                                    d['replyToFromMe'] as bool?,
                                                id: message.id,
                                                text: text,
                                                isMe: isMe,
                                                time: TimeOfDay.fromDateTime(
                                                  time,
                                                ),
                                                delivered: delivered,
                                                readBy: readBy,
                                                isDeleted: isDeleted,
                                                imageUrl: imageUrl,
                                                localPath:
                                                    localPreview ??
                                                    downloadedPath,
                                                fileUrl:
                                                    d['fileUrl'] as String?,
                                                fileName:
                                                    d['fileName'] as String?,
                                                fileSize: d['fileSize'] as int?,
                                                isStarred:
                                                    (d['starred'] ?? false) ==
                                                    true,
                                              ),
                                              startGroup:
                                                  prevIsMe == null ||
                                                  prevIsMe != isMe,
                                              endGroup:
                                                  nextIsMe == null ||
                                                  nextIsMe != isMe,
                                              peerUid: _peerUid ?? '',
                                              animateIn: animateIn,
                                              // upload state props for image messages
                                              isUploading:
                                                  _uploading[message.id] ==
                                                  true,
                                              uploadProgress:
                                                  _uploadProgress[message.id] ??
                                                  0.0,
                                              uploadFailed: _uploadFailed
                                                  .contains(message.id),
                                              onRetryUpload: () =>
                                                  _retryUpload(message.id),
                                              onTapFile: (m) => _openFile(m),
                                              onLongPress: isLocalPending
                                                  ? null
                                                  : () => _showMessageActions(
                                                      msgId: message.id,
                                                      isMe: isMe,
                                                      isStarred:
                                                          (d['starred'] ??
                                                              false) ==
                                                          true,
                                                      rawData: d,
                                                      localPath:
                                                          localPreview ??
                                                          downloadedPath,
                                                      imageUrl: imageUrl,
                                                      fileUrl:
                                                          d['fileUrl']
                                                              as String?,
                                                      fileName:
                                                          d['fileName']
                                                              as String?,
                                                    ),
                                              onSwipeRight: isLocalPending
                                                  ? null
                                                  : () => _beginReplyFromDoc(
                                                      message.id,
                                                      d,
                                                    ),
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                  },
                                ),
                        ),
                        RepaintBoundary(
                          child: Composer(
                            controller: _textCtrl,
                            onSend: _send,
                            onOpenAttach: _openAttachSheet,
                            replyPreview: _replyTarget == null
                                ? null
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _replyTarget!.isMe
                                            ? 'Membalas Anda'
                                            : 'Membalas Kontak',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      AnimatedOpacity(
                                        duration: const Duration(
                                          milliseconds: 200,
                                        ),
                                        opacity: _flashReply ? 0.3 : 1.0,
                                        child: Text(
                                          _replyTarget!.text,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white70,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                            onCancelReply: _cancelReply,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
