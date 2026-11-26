import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'msg.dart';

class Bubble extends StatefulWidget {
  const Bubble({
    super.key,
    required this.msg,
    required this.startGroup,
    required this.endGroup,
    required this.peerUid,
    this.animateIn = false,
    this.onLongPress,
    this.onSwipeRight,
    this.onTapReplySource,
    this.onTapFile,
    this.isUploading = false,
    this.uploadProgress,
    this.uploadFailed = false,
    this.onRetryUpload,
  });

  final Msg msg;
  final bool startGroup;
  final bool endGroup;
  final String peerUid;
  final bool animateIn;
  final VoidCallback? onLongPress;
  final VoidCallback? onSwipeRight;
  final VoidCallback? onTapReplySource;
  final Function(Msg)? onTapFile;
  // Upload state (used when showing locally pending uploads)
  final bool isUploading;
  final double? uploadProgress; // 0.0 - 1.0
  final bool uploadFailed;
  final VoidCallback? onRetryUpload;

  @override
  State<Bubble> createState() => _BubbleState();
}

class _BubbleState extends State<Bubble> with SingleTickerProviderStateMixin {
  final _dragOffsetX = ValueNotifier<double>(0.0);
  late final AnimationController _animCtrl;
  final _emojiRegex = RegExp(r'\p{Emoji}', unicode: true);
  late bool _isAppearVisible;

  @override
  void initState() {
    super.initState();
    _isAppearVisible = !widget.animateIn;
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      value: 0.0,
    );
    _dragOffsetX.addListener(() {
      _animCtrl.value = (_dragOffsetX.value / 60.0).clamp(0.0, 1.0);
    });
    if (widget.animateIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _isAppearVisible = true;
        });
      });
    }
  }

  @override
  void dispose() {
    _dragOffsetX.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  bool _isOnlyEmojis(String text) {
    if (text.trim().isEmpty) return false;
    final noEmojis = text.replaceAll(_emojiRegex, '');
    final noWhitespace = noEmojis.replaceAll(RegExp(r'\s'), '');
    return noWhitespace.isEmpty;
  }

  int _countEmojis(String text) {
    return _emojiRegex.allMatches(text.trim()).length;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    // Hanya handle swipe ke kanan
    final currentOffset = _dragOffsetX.value;
    final delta = details.primaryDelta ?? 0.0;
    if (currentOffset + delta > 0) {
      _dragOffsetX.value += delta;
    }
  }

  void _onDragEnd(DragEndDetails details) {
    if (_dragOffsetX.value > 60.0) {
      widget.onSwipeRight?.call();
    }
    // Animasikan kembali ke posisi semula
    _dragOffsetX.value = 0.0;
    _animCtrl.animateTo(0.0, curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final isEmojiOnly = _isOnlyEmojis(widget.msg.text);
    final emojiCount = _countEmojis(widget.msg.text);
    final isJumboEmoji = isEmojiOnly && emojiCount == 1;

    final align = widget.msg.isMe
        ? Alignment.centerRight
        : Alignment.centerLeft;

    final isPureImage =
        ((widget.msg.imageUrl?.isNotEmpty ?? false) ||
            (widget.msg.localPath?.isNotEmpty ?? false)) &&
        (widget.msg.text.isEmpty || widget.msg.text == 'Foto');
    final isFile = (widget.msg.fileUrl != null || widget.msg.fileName != null);
    final hasStar = widget.msg.isStarred && !widget.msg.isDeleted;
    final showMetaInline = !isPureImage && !isFile;
    final bubbleGradient = widget.msg.isMe
        ? const LinearGradient(
            colors: [Color(0x66A8D0FF), Color(0x4D7AB2F0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : const LinearGradient(
            colors: [Color(0x55FFFFFF), Color(0x33E9F0FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
    final bubbleBorderColor = widget.msg.isMe
        ? const Color(0x88D6EAFF)
        : const Color(0x66FFFFFF);
    final bubbleShadow = widget.msg.isMe
        ? const Color(0x332B517A)
        : const Color(0x220B1220);
    final fileCardColor = widget.msg.isMe
        ? Colors.white.withValues(alpha: 0.34)
        : Colors.white.withValues(alpha: 0.50);
    final metaChipColor = Colors.black.withValues(alpha: 0.24);
    final mediaBoxSize = math.min(
      MediaQuery.of(context).size.width * 0.6,
      220.0,
    );
    final mediaCacheExtent =
        (mediaBoxSize * MediaQuery.of(context).devicePixelRatio)
            .clamp(320.0, 1024.0)
            .round();
    // responsive file card width (like WhatsApp): up to 75% of screen, capped at 260
    final fileCardWidth = math.min(
      MediaQuery.of(context).size.width * 0.75,
      260.0,
    );
    final br = BorderRadius.only(
      topLeft: Radius.circular(
        widget.msg.isMe ? 16 : (widget.startGroup ? 16 : 6),
      ),
      topRight: Radius.circular(
        widget.msg.isMe ? (widget.startGroup ? 16 : 6) : 16,
      ),
      bottomLeft: Radius.circular(
        widget.msg.isMe ? 16 : (widget.endGroup ? 2 : 6),
      ),
      bottomRight: Radius.circular(
        widget.msg.isMe ? (widget.endGroup ? 2 : 6) : 16,
      ),
    );
    final double topSpacing = widget.startGroup ? 6.0 : 2.0;
    final double bottomSpacing = widget.endGroup ? 6.0 : 2.0;
    final bubbleMargin = EdgeInsets.only(
      left: widget.msg.isMe ? 64 : 8,
      right: widget.msg.isMe ? 8 : 64,
      top: topSpacing,
      bottom: bottomSpacing,
    );

    Widget content = Align(
      alignment: align,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          // Ikon reply di belakang
          AnimatedBuilder(
            animation: _animCtrl,
            builder: (context, child) {
              return Transform.scale(scale: _animCtrl.value, child: child);
            },
            child: const Padding(
              padding: EdgeInsets.only(left: 16.0),
              child: Icon(Icons.reply, color: Colors.white, size: 24),
            ),
          ),
          GestureDetector(
            onLongPress: widget.onLongPress,
            onHorizontalDragUpdate: _onDragUpdate,
            onHorizontalDragEnd: _onDragEnd,
            child: ValueListenableBuilder<double>(
              valueListenable: _dragOffsetX,
              builder: (context, offset, child) {
                return Transform.translate(
                  offset: Offset(offset, 0),
                  child: child,
                );
              },
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.9,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: bubbleMargin,
                      padding: isPureImage || isJumboEmoji
                          ? const EdgeInsets.all(4)
                          : const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                      decoration: BoxDecoration(
                        color: isPureImage || isJumboEmoji
                            ? Colors.transparent
                            : null,
                        gradient: isPureImage || isJumboEmoji
                            ? null
                            : bubbleGradient,
                        borderRadius: isPureImage || isJumboEmoji
                            ? BorderRadius.circular(12)
                            : br,
                        border: isPureImage || isJumboEmoji
                            ? null
                            : Border.all(color: bubbleBorderColor, width: 1.05),
                        boxShadow: isPureImage || isJumboEmoji
                            ? const []
                            : [
                                BoxShadow(
                                  color: bubbleShadow,
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                      ),
                      child: isJumboEmoji
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  widget.msg.text,
                                  style: const TextStyle(
                                    fontSize: 48,
                                    height: 1.0,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.3),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (hasStar) ...[
                                            _buildStarIcon(size: 14),
                                            const SizedBox(width: 3),
                                          ],
                                          Text(
                                            _fmtTime(widget.msg.time),
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Colors.white,
                                            ),
                                          ),
                                          if (widget.msg.isMe &&
                                              !widget.msg.isDeleted) ...[
                                            const SizedBox(width: 2),
                                            if (!widget.msg.delivered)
                                              const Icon(
                                                Icons.check,
                                                size: 16,
                                                color: Colors.white,
                                              ),
                                            if (widget.msg.delivered &&
                                                !(widget.msg.readBy.contains(
                                                  widget.peerUid,
                                                )))
                                              const Icon(
                                                Icons.done_all,
                                                size: 16,
                                                color: Colors.white,
                                              ),
                                            if (widget.msg.readBy.contains(
                                              widget.peerUid,
                                            ))
                                              const Icon(
                                                Icons.done_all,
                                                size: 16,
                                                color: Color(0xFF87CEFA),
                                              ), // Light Sky Blue
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            )
                          : (isFile
                                ? Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // If file was deleted for everyone, show a unified deleted message
                                      if (widget.msg.isDeleted)
                                        Padding(
                                          // shift slightly to the right so the deleted label aligns better inside the bubble
                                          padding: const EdgeInsets.only(
                                            top: 0,
                                            left: 12,
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.max,
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  // reuse message text when available, otherwise default label
                                                  (widget.msg.text.isNotEmpty
                                                      ? widget.msg.text
                                                      : 'Pesan ini telah dihapus'),
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 15,
                                                    height: 1.25,
                                                    fontStyle: FontStyle.italic,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 16),
                                              Text(
                                                _fmtTime(widget.msg.time),
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      else ...[
                                        // Wrap file card and overlay in a Stack so upload overlay covers the card
                                        Stack(
                                          children: [
                                            GestureDetector(
                                              onTap: () => widget.onTapFile
                                                  ?.call(widget.msg),
                                              child: Container(
                                                margin: const EdgeInsets.only(
                                                  top: 8,
                                                ),
                                                width: fileCardWidth,
                                                height: 72,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 8,
                                                    ),
                                                decoration: BoxDecoration(
                                                  // When the file is sent by me, show it on the same bubble background
                                                  color: fileCardColor,
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  border: Border.all(
                                                    color: Colors.white
                                                        .withValues(
                                                          alpha: 0.42,
                                                        ),
                                                  ),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black
                                                          .withOpacity(0.06),
                                                      blurRadius: 6,
                                                    ),
                                                  ],
                                                ),
                                                child: Row(
                                                  children: [
                                                    Container(
                                                      width: 48,
                                                      height: 48,
                                                      decoration: BoxDecoration(
                                                        color:
                                                            (widget.msg.fileName ??
                                                                    '')
                                                                .toLowerCase()
                                                                .endsWith(
                                                                  '.pdf',
                                                                )
                                                            ? Colors.red[700]
                                                            : Colors
                                                                  .blueGrey[200],
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              6,
                                                            ),
                                                      ),
                                                      child: Icon(
                                                        (widget.msg.fileName ??
                                                                    '')
                                                                .toLowerCase()
                                                                .endsWith(
                                                                  '.pdf',
                                                                )
                                                            ? Icons
                                                                  .picture_as_pdf
                                                            : Icons
                                                                  .insert_drive_file,
                                                        // use white icon for colored badge (pdf or file badge) for contrast
                                                        color: Colors.white,
                                                        size: 22,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: Text(
                                                        widget.msg.fileName ??
                                                            'file',
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color: Colors.white,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            if (widget.isUploading ||
                                                widget.uploadFailed)
                                              Positioned.fill(
                                                child: Container(
                                                  margin: const EdgeInsets.only(
                                                    top: 8,
                                                  ),
                                                  width: fileCardWidth,
                                                  height: 72,
                                                  decoration: BoxDecoration(
                                                    color: Colors.black
                                                        .withOpacity(0.35),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                  ),
                                                  child: Center(
                                                    child: widget.isUploading
                                                        ? Row(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            children: [
                                                              SizedBox(
                                                                width: 28,
                                                                height: 28,
                                                                child: CircularProgressIndicator(
                                                                  strokeWidth:
                                                                      2.5,
                                                                  value: widget
                                                                      .uploadProgress,
                                                                  color: Colors
                                                                      .white,
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                width: 10,
                                                              ),
                                                              if (widget
                                                                      .uploadProgress !=
                                                                  null)
                                                                Text(
                                                                  '${(widget.uploadProgress! * 100).toStringAsFixed(0)}%',
                                                                  style: const TextStyle(
                                                                    color: Colors
                                                                        .white,
                                                                  ),
                                                                ),
                                                            ],
                                                          )
                                                        : Column(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            children: [
                                                              const Icon(
                                                                Icons
                                                                    .error_outline,
                                                                color: Colors
                                                                    .white,
                                                                size: 28,
                                                              ),
                                                              const SizedBox(
                                                                height: 8,
                                                              ),
                                                              TextButton(
                                                                onPressed: widget
                                                                    .onRetryUpload,
                                                                child: const Text(
                                                                  'Ulangi',
                                                                  style: TextStyle(
                                                                    color: Colors
                                                                        .white,
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        // time and ticks under the file card
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 6,
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            mainAxisAlignment:
                                                MainAxisAlignment.end,
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: metaChipColor,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color: Colors.white
                                                        .withValues(
                                                          alpha: 0.25,
                                                        ),
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    if (hasStar) ...[
                                                      _buildStarIcon(size: 14),
                                                      const SizedBox(width: 4),
                                                    ],
                                                    Text(
                                                      _fmtTime(widget.msg.time),
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                    if (widget.msg.isMe &&
                                                        !widget
                                                            .msg
                                                            .isDeleted) ...[
                                                      const SizedBox(width: 6),
                                                      if (!widget.msg.delivered)
                                                        const Icon(
                                                          Icons.check,
                                                          size: 16,
                                                          color: Colors.white,
                                                        ),
                                                      if (widget
                                                              .msg
                                                              .delivered &&
                                                          !(widget.msg.readBy
                                                              .contains(
                                                                widget.peerUid,
                                                              )))
                                                        const Icon(
                                                          Icons.done_all,
                                                          size: 16,
                                                          color: Colors.white,
                                                        ),
                                                      if (widget.msg.readBy
                                                          .contains(
                                                            widget.peerUid,
                                                          ))
                                                        const Icon(
                                                          Icons.done_all,
                                                          size: 16,
                                                          color: Color(
                                                            0xFF34B7F1,
                                                          ),
                                                        ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  )
                                : Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Flexible(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            // Reply preview header (if this message is a reply to another message)
                                            if ((widget.msg.replyToText ?? '')
                                                .isNotEmpty)
                                              InkWell(
                                                onTap: widget.onTapReplySource,
                                                child: Container(
                                                  margin: const EdgeInsets.only(
                                                    bottom: 6,
                                                  ),
                                                  padding:
                                                      const EdgeInsets.fromLTRB(
                                                        10,
                                                        8,
                                                        10,
                                                        8,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white
                                                        .withValues(
                                                          alpha: 0.22,
                                                        ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                    border: Border(
                                                      left: BorderSide(
                                                        color:
                                                            widget
                                                                    .msg
                                                                    .replyToFromMe ==
                                                                true
                                                            ? const Color(
                                                                0xFF34B7F1,
                                                              ) // blue when replying to self
                                                            : Colors
                                                                  .green, // green when replying to peer
                                                        width: 3,
                                                      ),
                                                    ),
                                                  ),
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        widget.msg.replyToFromMe ==
                                                                true
                                                            ? 'Anda'
                                                            : 'Kontak',
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        widget.msg.replyToText!,
                                                        maxLines: 2,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: const TextStyle(
                                                          fontSize: 12.5,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            if ((widget
                                                        .msg
                                                        .imageUrl
                                                        ?.isNotEmpty ??
                                                    false) ||
                                                (widget
                                                        .msg
                                                        .localPath
                                                        ?.isNotEmpty ??
                                                    false))
                                              Stack(
                                                children: [
                                                  // tappable hero image -> opens full-screen zoomable viewer
                                                  GestureDetector(
                                                    onTap: () =>
                                                        _openZoom(context),
                                                    child: Hero(
                                                      tag: widget.msg.id,
                                                      child: ClipRRect(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                        child: SizedBox(
                                                          width: mediaBoxSize,
                                                          height: mediaBoxSize,
                                                          child:
                                                              (widget
                                                                      .msg
                                                                      .localPath
                                                                      ?.isNotEmpty ??
                                                                  false)
                                                              ? Image.file(
                                                                  File(
                                                                    widget
                                                                        .msg
                                                                        .localPath!,
                                                                  ),
                                                                  fit: BoxFit
                                                                      .cover,
                                                                  filterQuality:
                                                                      FilterQuality
                                                                          .low,
                                                                  cacheWidth:
                                                                      mediaCacheExtent,
                                                                  cacheHeight:
                                                                      mediaCacheExtent,
                                                                  errorBuilder: (_, __, ___) => Container(
                                                                    color: Colors
                                                                        .black12,
                                                                    child: const Center(
                                                                      child: Icon(
                                                                        Icons
                                                                            .image,
                                                                        size:
                                                                            40,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                )
                                                              : Image.network(
                                                                  widget
                                                                      .msg
                                                                      .imageUrl!,
                                                                  fit: BoxFit
                                                                      .cover,
                                                                  filterQuality:
                                                                      FilterQuality
                                                                          .low,
                                                                  cacheWidth:
                                                                      mediaCacheExtent,
                                                                  cacheHeight:
                                                                      mediaCacheExtent,
                                                                  errorBuilder: (_, __, ___) => Container(
                                                                    color: Colors
                                                                        .black12,
                                                                    child: const Center(
                                                                      child: Icon(
                                                                        Icons
                                                                            .broken_image,
                                                                        size:
                                                                            40,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  // Upload overlay for local pending uploads (inside Stack)
                                                  if (widget.isUploading ||
                                                      widget.uploadFailed)
                                                    Positioned.fill(
                                                      child: Align(
                                                        alignment:
                                                            Alignment.center,
                                                        child: Container(
                                                          width: mediaBoxSize,
                                                          height: mediaBoxSize,
                                                          decoration: BoxDecoration(
                                                            color: Colors.black
                                                                .withOpacity(
                                                                  0.35,
                                                                ),
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  12,
                                                                ),
                                                          ),
                                                          child: Center(
                                                            child:
                                                                widget
                                                                    .isUploading
                                                                ? Column(
                                                                    mainAxisSize:
                                                                        MainAxisSize
                                                                            .min,
                                                                    children: [
                                                                      const CircularProgressIndicator(
                                                                        strokeWidth:
                                                                            2.5,
                                                                        color: Colors
                                                                            .white,
                                                                      ),
                                                                      const SizedBox(
                                                                        height:
                                                                            8,
                                                                      ),
                                                                      if (widget
                                                                              .uploadProgress !=
                                                                          null)
                                                                        Text(
                                                                          '${(widget.uploadProgress! * 100).toStringAsFixed(0)}%',
                                                                          style: const TextStyle(
                                                                            color:
                                                                                Colors.white,
                                                                          ),
                                                                        ),
                                                                    ],
                                                                  )
                                                                : Column(
                                                                    mainAxisSize:
                                                                        MainAxisSize
                                                                            .min,
                                                                    children: [
                                                                      const Icon(
                                                                        Icons
                                                                            .error_outline,
                                                                        color: Colors
                                                                            .white,
                                                                        size:
                                                                            28,
                                                                      ),
                                                                      const SizedBox(
                                                                        height:
                                                                            8,
                                                                      ),
                                                                      TextButton(
                                                                        onPressed:
                                                                            widget.onRetryUpload,
                                                                        child: const Text(
                                                                          'Ulangi',
                                                                          style: TextStyle(
                                                                            color:
                                                                                Colors.white,
                                                                          ),
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            // For pure-image messages, show the time and delivery/read ticks below the image
                                            if (isPureImage)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  top: 6,
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.end,
                                                  children: [
                                                    Container(
                                                      constraints:
                                                          BoxConstraints(
                                                            maxWidth:
                                                                mediaBoxSize,
                                                          ),
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 8,
                                                            vertical: 4,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: metaChipColor,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                        border: Border.all(
                                                          color: Colors.white
                                                              .withValues(
                                                                alpha: 0.25,
                                                              ),
                                                        ),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          if (hasStar) ...[
                                                            _buildStarIcon(
                                                              size: 14,
                                                            ),
                                                            const SizedBox(
                                                              width: 4,
                                                            ),
                                                          ],
                                                          Flexible(
                                                            child: Text(
                                                              _fmtTime(
                                                                widget.msg.time,
                                                              ),
                                                              style:
                                                                  const TextStyle(
                                                                    fontSize:
                                                                        11,
                                                                    color: Colors
                                                                        .white,
                                                                  ),
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                            ),
                                                          ),
                                                          if (widget.msg.isMe &&
                                                              !widget
                                                                  .msg
                                                                  .isDeleted) ...[
                                                            const SizedBox(
                                                              width: 6,
                                                            ),
                                                            if (!widget
                                                                .msg
                                                                .delivered)
                                                              const Icon(
                                                                Icons.check,
                                                                size: 16,
                                                                color: Colors
                                                                    .white,
                                                              ),
                                                            if (widget
                                                                    .msg
                                                                    .delivered &&
                                                                !(widget
                                                                    .msg
                                                                    .readBy
                                                                    .contains(
                                                                      widget
                                                                          .peerUid,
                                                                    )))
                                                              const Icon(
                                                                Icons.done_all,
                                                                size: 16,
                                                                color: Colors
                                                                    .white70,
                                                              ),
                                                            if (widget
                                                                .msg
                                                                .readBy
                                                                .contains(
                                                                  widget
                                                                      .peerUid,
                                                                ))
                                                              const Icon(
                                                                Icons.done_all,
                                                                size: 16,
                                                                color: Color(
                                                                  0xFF34B7F1,
                                                                ),
                                                              ),
                                                          ],
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            if (widget.msg.text.isNotEmpty &&
                                                (widget.msg.text != 'Foto'))
                                              widget.msg.isDeleted
                                                  ? Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                            top: 0,
                                                            left: 12,
                                                          ),
                                                      child: Align(
                                                        alignment: Alignment
                                                            .centerLeft,
                                                        child: Text(
                                                          widget.msg.text,
                                                          style: TextStyle(
                                                            fontSize: 15,
                                                            height: 1.25,
                                                            fontStyle: FontStyle
                                                                .italic,
                                                            color:
                                                                Colors.white,
                                                          ),
                                                        ),
                                                      ),
                                                    )
                                                  : Text(
                                                      widget.msg.text,
                                                      style: TextStyle(
                                                        fontSize: 15,
                                                        height: 1.25,
                                                        fontStyle:
                                                            FontStyle.normal,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                          ],
                                        ),
                                      ),
                                      // For non-image messages show time and ticks to the right when not starred
                                      if (showMetaInline) ...[
                                        const SizedBox(width: 6),
                                        if (hasStar) ...[
                                          _buildStarIcon(size: 14),
                                          const SizedBox(width: 3),
                                        ],
                                        Text(
                                          _fmtTime(widget.msg.time),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.white,
                                          ),
                                        ),
                                        if (widget.msg.isMe &&
                                            !widget.msg.isDeleted) ...[
                                          const SizedBox(width: 2),
                                          if (!widget.msg.delivered)
                                            const Icon(
                                              Icons.check,
                                              size: 16,
                                              color: Colors.white70,
                                            ), // ✓
                                          if (widget.msg.delivered &&
                                              !(widget.msg.readBy.contains(
                                                widget.peerUid,
                                              )))
                                            const Icon(
                                              Icons.done_all,
                                              size: 16,
                                              color: Colors.white70,
                                            ), // ✓✓ abu
                                          if (widget.msg.readBy.contains(
                                            widget.peerUid,
                                          ))
                                            const Icon(
                                              Icons.done_all,
                                              size: 16,
                                              color: Color(0xFF34B7F1),
                                            ), // ✓✓ biru
                                        ],
                                      ],
                                    ],
                                  )),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (!widget.animateIn) {
      return content;
    }

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 170),
      curve: Curves.easeOut,
      opacity: _isAppearVisible ? 1.0 : 0.0,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        offset: _isAppearVisible
            ? Offset.zero
            : (widget.msg.isMe
                ? const Offset(0.08, 0)
                : const Offset(-0.08, 0)),
        child: content,
      ),
    );
  }

  Widget _buildStarIcon({double size = 14}) {
    return Text(
      String.fromCharCode(Icons.star.codePoint),
      style: TextStyle(
        fontSize: size,
        fontFamily: Icons.star.fontFamily,
        package: Icons.star.fontPackage,
        color: const Color(0xFFFFD54F),
        shadows: [
          Shadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
    );
  }

  String _fmtTime(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h.$m';
  }

  void _openZoom(BuildContext context) {
    final imgUrl = widget.msg.imageUrl;
    final local = widget.msg.localPath;
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, __, ___) => ZoomImagePage(
          tag: widget.msg.id,
          imageUrl: imgUrl,
          localPath: local,
        ),
      ),
    );
  }
}

class ZoomImagePage extends StatelessWidget {
  const ZoomImagePage({
    super.key,
    required this.tag,
    this.imageUrl,
    this.localPath,
  });

  final String tag;
  final String? imageUrl;
  final String? localPath;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.95),
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Hero(
                tag: tag,
                child: InteractiveViewer(
                  minScale: 1.0,
                  maxScale: 5.0,
                  child: localPath != null && localPath!.isNotEmpty
                      ? Image.file(File(localPath!), fit: BoxFit.contain)
                      : (imageUrl != null && imageUrl!.isNotEmpty)
                      ? Image.network(imageUrl!, fit: BoxFit.contain)
                      : const SizedBox.shrink(),
                ),
              ),
            ),
            Positioned(
              top: 12,
              left: 12,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
