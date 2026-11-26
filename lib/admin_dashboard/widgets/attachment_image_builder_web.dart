import 'dart:html' as html;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:ui_web' as ui_web;

int _attachmentImageViewCounter = 0;

Widget buildAttachmentImage({
  required String url,
  required VoidCallback onError,
  required Widget errorWidget,
}) {
  final viewType = 'attachment-image-view-${_attachmentImageViewCounter++}';
  final loaded = ValueNotifier<bool>(false);
  final failed = ValueNotifier<bool>(false);

  bool isRegistered = false;
  void registerFactory() {
    if (isRegistered) return;
    isRegistered = true;
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int _) {
      final container = html.DivElement()
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.display = 'flex'
        ..style.justifyContent = 'center'
        ..style.alignItems = 'center'
        ..style.backgroundColor = 'transparent'
        ..style.overflow = 'hidden';

      final image = html.ImageElement()
        ..src = url
        ..style.maxWidth = '100%'
        ..style.maxHeight = '100%'
        ..style.objectFit = 'contain';

      image.onLoad.listen((_) {
        loaded.value = true;
      });
      image.onError.listen((_) {
        failed.value = true;
      });

      container.append(image);
      return container;
    });
  }

  registerFactory();

  final htmlView = HtmlElementView(viewType: viewType);

  return ClipRRect(
    borderRadius: BorderRadius.circular(18),
    child: ValueListenableBuilder<bool>(
      valueListenable: failed,
      builder: (context, isFailed, _) {
        if (isFailed) {
          onError();
          return errorWidget;
        }
        return Stack(
          fit: StackFit.expand,
          children: [
            htmlView,
            ValueListenableBuilder<bool>(
              valueListenable: loaded,
              builder: (context, isLoaded, __) {
                if (isLoaded) {
                  return const SizedBox.shrink();
                }
                return const Center(
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(),
                  ),
                );
              },
            ),
          ],
        );
      },
    ),
  );
}
