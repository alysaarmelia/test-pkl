import 'dart:ui';
import 'package:flutter/material.dart';

class ReplyPreviewBar extends StatelessWidget {
  const ReplyPreviewBar({
    super.key,
    required this.visible,
    required this.text,
    required this.isImage,
    required this.onClose,
  });

  final bool visible;
  final String text;
  final bool isImage;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.16),
              border: Border.all(color: Colors.white.withOpacity(0.35)),
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 3, height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFF34B7F1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Membalas', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
                      const SizedBox(height: 2),
                      Text(isImage ? '[Foto]' : text,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: onClose,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}