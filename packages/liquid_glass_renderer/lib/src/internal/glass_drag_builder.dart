import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

@internal
class GlassDragBuilder extends StatefulWidget {
  const GlassDragBuilder({required this.builder, this.behavior = HitTestBehavior.opaque, this.child, super.key});

  final HitTestBehavior behavior;

  final ValueWidgetBuilder<Offset?> builder;

  final Widget? child;

  @override
  State<GlassDragBuilder> createState() => _GlassDragBuilderState();
}

class _GlassDragBuilderState extends State<GlassDragBuilder> {
  Offset? currentDragOffset;

  bool get isDragging => currentDragOffset != null;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: widget.behavior,
      // Pointer events can be delivered after this state is disposed
      // (drag-then-navigate); guard every callback or setState throws
      // "Null check operator used on a null value" via _element!.
      onPointerDown: (event) {
        if (!mounted) return;
        setState(() {
          currentDragOffset = Offset.zero;
        });
      },
      onPointerMove: (event) {
        if (!mounted) return;
        setState(() {
          currentDragOffset = (currentDragOffset ?? Offset.zero) + event.delta;
        });
      },
      onPointerUp: (event) {
        if (!mounted) return;
        setState(() {
          currentDragOffset = null;
        });
      },
      child: widget.builder(context, currentDragOffset, widget.child),
    );
  }
}
