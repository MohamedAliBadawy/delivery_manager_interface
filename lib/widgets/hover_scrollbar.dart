import 'package:flutter/material.dart';

class HoverScrollbar extends StatefulWidget {
  final Widget child;
  final ScrollController controller;
  final Axis scrollDirection;

  const HoverScrollbar({
    super.key,
    required this.child,
    required this.controller,
    this.scrollDirection = Axis.vertical,
  });

  @override
  State<HoverScrollbar> createState() => _HoverScrollbarState();
}

class _HoverScrollbarState extends State<HoverScrollbar> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Scrollbar(
        controller: widget.controller,
        thumbVisibility: _isHovered,
        trackVisibility: _isHovered,
        notificationPredicate: (notification) => notification.depth == 0,
        child: widget.child,
      ),
    );
  }
}
