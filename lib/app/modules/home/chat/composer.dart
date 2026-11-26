import 'package:flutter/material.dart';

class Composer extends StatelessWidget {
  const Composer({
    super.key,
    required this.controller,
    required this.onSend,
    required this.onOpenAttach,
    this.replyPreview,
    this.onCancelReply,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onOpenAttach;
  final Widget? replyPreview;
  final VoidCallback? onCancelReply;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (replyPreview != null) ...[
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color.fromRGBO(255, 255, 255, 0.22),
                      Color.fromRGBO(255, 255, 255, 0.12),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
                child: Row(
                  children: [
                    const Icon(Icons.reply, size: 18, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(child: replyPreview!),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: onCancelReply,
                      tooltip: 'Batal balas',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
            ],
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color.fromRGBO(255, 255, 255, 0.2),
                    Color.fromRGBO(201, 228, 255, 0.12),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.35),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.add, color: Colors.white),
                    onPressed: onOpenAttach,
                  ),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: TextField(
                        controller: controller,
                        minLines: 1,
                        maxLines: 4,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Ketik pesan…',
                          hintStyle: TextStyle(color: Colors.white70),
                          border: InputBorder.none,
                        ),
                        onSubmitted: (_) => onSend(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 46,
                    height: 46,
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.26),
                        borderRadius: BorderRadius.circular(23),
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: 46,
                          height: 46,
                        ),
                        iconSize: 22,
                        icon: const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                        ),
                        onPressed: onSend,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
