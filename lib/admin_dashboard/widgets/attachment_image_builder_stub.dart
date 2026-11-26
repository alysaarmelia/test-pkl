import 'package:flutter/material.dart';

Widget buildAttachmentImage({
  required String url,
  required VoidCallback onError,
  required Widget errorWidget,
}) {
  return InteractiveViewer(
    minScale: 0.9,
    maxScale: 4,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Image.network(
        url,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) {
            return child;
          }
          final expected = loadingProgress.expectedTotalBytes;
          final progress = expected != null && expected > 0
              ? loadingProgress.cumulativeBytesLoaded / expected
              : null;
          return Center(
            child: SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(value: progress),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          onError();
          return errorWidget;
        },
      ),
    ),
  );
}
