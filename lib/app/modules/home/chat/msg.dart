import 'package:flutter/material.dart';

class Msg {
  final String id;
  final String text;
  final bool isMe;
  final TimeOfDay time;
  final bool delivered;
  final List<String> readBy;
  final bool isDeleted;
  final String? imageUrl;
  final String? localPath;
  final Map<String, dynamic>? replyOf; // {msgId, text, type, senderId, imageUrl}
  final String? replyToId;
  final String? replyToText;
  final bool? replyToFromMe;
  final String? replyToImageUrl;
  final String meUid;
  final String? fileUrl;
  final String? fileName;
  final int? fileSize;
  final bool isStarred;

  const Msg({
    required this.id,
    required this.text,
    required this.isMe,
    required this.time,
    this.delivered = false,
    this.readBy = const [],
    this.isDeleted = false,
    this.imageUrl,
    this.localPath,
    this.replyOf,
    this.replyToId,
    this.replyToText,
    this.replyToFromMe,
    this.replyToImageUrl,
    this.meUid = '',
  this.fileUrl,
  this.fileName,
  this.fileSize,
  this.isStarred = false,
  
  });
}