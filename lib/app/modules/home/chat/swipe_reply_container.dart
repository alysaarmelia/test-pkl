import 'package:flutter/material.dart';

class SwipeReplyContainer extends StatefulWidget {
  const SwipeReplyContainer({super.key, required this.child, required this.onReply});
  final Widget child;
  final VoidCallback onReply;

  @override
  State<SwipeReplyContainer> createState() => _SwipeReplyContainerState();
}

class _SwipeReplyContainerState extends State<SwipeReplyContainer> {
  double _dx = 0;
  static const double _trigger = 70;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.centerLeft,
      children: [
        Opacity(
          opacity: (_dx / _trigger).clamp(0.0, 1.0),
          child: const Padding(
            padding: EdgeInsets.only(left: 16.0),
            child: Icon(Icons.reply, color: Colors.white70),
          ),
        ),
        GestureDetector(
          onHorizontalDragUpdate: (details) {
            setState(() {
              _dx += details.delta.dx;
              if (_dx < 0) _dx = 0;
              if (_dx > 120) _dx = 120;
            });
          },
          onHorizontalDragEnd: (_) {
            if (_dx > _trigger) widget.onReply();
            setState(() { _dx = 0; });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            transform: Matrix4.translationValues(_dx, 0, 0),
            curve: Curves.easeOut,
            child: widget.child,
          ),
        ),
      ],
    );
  }
}