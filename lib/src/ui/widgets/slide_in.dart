import 'package:material_ui/material_ui.dart';

import '../theme.dart';

/// Slides a message down into place and back up when it goes, growing its
/// space as it comes so nothing below jumps. Snaps under reduced motion.
/// Give [child] a key that changes with its text, so a new message swaps in.
class SlideIn extends StatelessWidget {
  const SlideIn({this.child, super.key});

  final Widget? child;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: motion(context, 280),
    switchInCurve: Curves.easeOutCubic,
    switchOutCurve: Curves.easeInCubic,
    layoutBuilder: (current, previous) =>
        Stack(fit: StackFit.passthrough, children: [...previous, ?current]),
    transitionBuilder: (child, animation) => SizeTransition(
      sizeFactor: animation,
      alignment: Alignment.topCenter,
      child: FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, -0.5),
            end: Offset.zero,
          ).animate(animation),
          // Full width, so start- and end-aligned messages keep their side.
          child: SizedBox(width: double.infinity, child: child),
        ),
      ),
    ),
    child: child ?? const SizedBox.shrink(),
  );
}
