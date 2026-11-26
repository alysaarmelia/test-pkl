import 'package:flutter/material.dart';

import 'attachment_image_builder_stub.dart'
    if (dart.library.html) 'attachment_image_builder_web.dart' as impl;

Widget buildAttachmentImage({
  required String url,
  required VoidCallback onError,
  required Widget errorWidget,
}) =>
    impl.buildAttachmentImage(
      url: url,
      onError: onError,
      errorWidget: errorWidget,
    );

