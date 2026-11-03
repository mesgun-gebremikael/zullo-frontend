import 'l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'theme/zullo_palette.dart';

class SwipePage extends StatelessWidget {
  final bool isLoading, hasActiveProfile, hasUnreadMessages;
  final ValueListenable<Offset> dragListenable;
  final Widget? nextCard;
  final Widget activeCard, emptyState;
  final VoidCallback onOpenRadiusSheet,
      onOpenMatchesPage,
      onSwipeLeft,
      onSwipeUp,
      onSwipeRight;
  final VoidCallback? onRewind;
  const SwipePage(
      {super.key,
      this.onRewind,
      required this.isLoading,
      required this.hasActiveProfile,
      required this.hasUnreadMessages,
      required this.dragListenable,
      required this.nextCard,
      required this.activeCard,
      required this.emptyState,
      required this.onOpenRadiusSheet,
      required this.onOpenMatchesPage,
      required this.onSwipeLeft,
      required this.onSwipeUp,
      required this.onSwipeRight});
  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: hasActiveProfile ? Colors.black : ZulloPalette.canvas,
      body: SafeArea(
          bottom: false,
          child: Column(children: [
            Align(
                alignment: AlignmentDirectional.centerStart,
                child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: IconButton(
                        tooltip: context.l10n.discoveryFilters,
                        onPressed: onOpenRadiusSheet,
                        icon: Icon(Icons.tune_rounded,
                            color: hasActiveProfile
                                ? Colors.white
                                : ZulloPalette.ink)))),
            Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : hasActiveProfile
                        ? Padding(
                            padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
                            child: ClipRRect(
                                borderRadius: BorderRadius.circular(30),
                                child: Stack(fit: StackFit.expand, children: [
                                  if (nextCard != null) nextCard!,
                                  activeCard,
                                  Positioned(
                                      left: 0,
                                      right: 0,
                                      bottom: 12,
                                      child: _actions()),
                                ])))
                        : emptyState),
          ])));
  Widget _actions() => ValueListenableBuilder<Offset>(
      valueListenable: dragListenable,
      builder: (context, drag, _) =>
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _action(context.l10n.rewindLastSwipe, Icons.replay_rounded,
                const Color(0xFFFFB533), onRewind,
                size: 48, iconSize: 27),
            const SizedBox(width: 12),
            _action(context.l10n.skip, Icons.close_rounded,
                const Color(0xFFFF2D75), onSwipeLeft,
                size: 62, iconSize: 38),
            const SizedBox(width: 12),
            _action('Superlike', Icons.star_rounded, const Color(0xFF1EADFF),
                onSwipeUp,
                size: 52, iconSize: 30),
            const SizedBox(width: 12),
            _action(context.l10n.likeAction, Icons.favorite_rounded,
                const Color(0xFF77E539), onSwipeRight,
                size: 62, iconSize: 36),
          ]));
  Widget _action(String label, IconData icon, Color color, VoidCallback? action,
          {required double size, required double iconSize}) =>
      SizedBox.square(
          dimension: size,
          child: IconButton(
              tooltip: label,
              onPressed: action,
              style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF111317),
                  disabledBackgroundColor: const Color(0xFF111317),
                  foregroundColor: color,
                  disabledForegroundColor: color.withValues(alpha: .35),
                  padding: EdgeInsets.zero),
              icon: Icon(icon, size: iconSize)));
}
