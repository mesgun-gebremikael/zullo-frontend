import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

class SwipePage extends StatelessWidget {
  final bool isLoading;
  final bool hasActiveProfile;
  final bool hasUnreadMessages;

  final ValueListenable<Offset> dragListenable;

  final Widget? nextCard;
  final Widget activeCard;
  final Widget emptyState;

  final VoidCallback onOpenRadiusSheet;
  final VoidCallback onOpenMatchesPage;
  final VoidCallback onLogout;
  final VoidCallback onOpenEditProfile;
  final VoidCallback onSwipeLeft;
  final VoidCallback onSwipeUp;
  final VoidCallback onSwipeRight;

  final VoidCallback? onRewind;

  const SwipePage({
    super.key,
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
    required this.onLogout,
    required this.onOpenEditProfile,
    required this.onSwipeLeft,
    required this.onSwipeUp,
    required this.onSwipeRight,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                const Positioned.fill(
                  child: ColoredBox(color: Colors.black),
                ),
                Positioned.fill(
                  child: Stack(
                    children: [
                      if (nextCard != null) nextCard!,
                      Positioned.fill(
                        child: hasActiveProfile ? activeCard : emptyState,
                      ),
                    ],
                  ),
                ),
                _TopOverlayBar(
                  onOpenRadiusSheet: onOpenRadiusSheet,
                  onLogout: onLogout,
                  onRewind: onRewind,
                ),
                if (hasActiveProfile)
                  _BottomActionBar(
                    dragListenable: dragListenable,
                    onOpenEditProfile: onOpenEditProfile,
                    onSwipeLeft: onSwipeLeft,
                    onSwipeUp: onSwipeUp,
                    onSwipeRight: onSwipeRight,
                  ),
              ],
            ),
    );
  }
}

class _TopOverlayBar extends StatelessWidget {
  final VoidCallback onOpenRadiusSheet;
  final VoidCallback onLogout;
  final VoidCallback? onRewind;

  const _TopOverlayBar({
    required this.onOpenRadiusSheet,
    required this.onLogout,
    this.onRewind,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.50),
                Colors.black.withOpacity(0.22),
                Colors.transparent,
              ],
            ),
          ),
          child: Row(
            children: [
              if (onRewind != null)
                _TopIconButton(icon: Icons.undo_rounded, onTap: onRewind!),
              _TopIconButton(
                icon: Icons.tune_rounded,
                onTap: onOpenRadiusSheet,
              ),
              const SizedBox(width: 12),
              const Expanded(
                  child: Center(
                      child: Text('För dig',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 21,
                              fontWeight: FontWeight.w800)))),
              const SizedBox(width: 12),
              _TopIconButton(
                icon: Icons.logout,
                onTap: onLogout,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomActionBar extends StatelessWidget {
  final ValueListenable<Offset> dragListenable;
  final VoidCallback onOpenEditProfile;
  final VoidCallback onSwipeLeft;
  final VoidCallback onSwipeUp;
  final VoidCallback onSwipeRight;

  const _BottomActionBar({
    required this.dragListenable,
    required this.onOpenEditProfile,
    required this.onSwipeLeft,
    required this.onSwipeUp,
    required this.onSwipeRight,
  });

  double _likeProgress(Offset drag) {
    return (drag.dx / 140).clamp(0.0, 1.0).toDouble();
  }

  double _nopeProgress(Offset drag) {
    return (-drag.dx / 140).clamp(0.0, 1.0).toDouble();
  }

  double _superProgress(Offset drag) {
    final raw = (-drag.dy / 170).clamp(0.0, 1.0).toDouble();
    if (drag.dy >= 0) return 0.0;
    if (drag.dy.abs() < drag.dx.abs() * 0.55) return 0.0;
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Offset>(
      valueListenable: dragListenable,
      builder: (context, drag, _) {
        final likeProgress = _likeProgress(drag);
        final nopeProgress = _nopeProgress(drag);
        final superProgress = _superProgress(drag);
        final isDraggingAny =
            likeProgress > 0 || nopeProgress > 0 || superProgress > 0;

        return Positioned(
          left: 0,
          right: 0,
          bottom: 18,
          child: SafeArea(
            top: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedScale(
                  duration: const Duration(milliseconds: 90),
                  scale: nopeProgress > 0 ? 1.22 : 1.0,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 90),
                    opacity: likeProgress > 0 || superProgress > 0 ? 0.10 : 1.0,
                    child: _SwipeActionButton(
                      size: 62,
                      onTap: onSwipeLeft,
                      label: 'Passa',
                      child: const _ThickXIcon(
                        color: Color(0xFFFF2D75),
                        size: 34,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                AnimatedScale(
                  duration: const Duration(milliseconds: 90),
                  scale: superProgress > 0 ? 1.22 : 1.0,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 90),
                    opacity: likeProgress > 0 || nopeProgress > 0 ? 0.10 : 1.0,
                    child: _SwipeActionButton(
                      size: 54,
                      onTap: onSwipeUp,
                      label: 'Superlike',
                      child: const Icon(
                        Icons.star_rounded,
                        size: 28,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                AnimatedScale(
                  duration: const Duration(milliseconds: 90),
                  scale: likeProgress > 0 ? 1.22 : 1.0,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 90),
                    opacity: nopeProgress > 0 || superProgress > 0 ? 0.10 : 1.0,
                    child: _SwipeActionButton(
                      size: 62,
                      onTap: onSwipeRight,
                      label: 'Gilla',
                      child: const Icon(
                        Icons.favorite,
                        size: 34,
                        color: Color(0xFF7BEA3A),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 90),
                  opacity: isDraggingAny ? 0.10 : 1.0,
                  child: _SwipeActionButton(
                    size: 52,
                    onTap: onOpenEditProfile,
                    label: 'Redigera profil',
                    child: const Icon(
                      Icons.edit_outlined,
                      size: 24,
                      color: Colors.lightBlue,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SwipeActionButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final String label;
  final double size;
  const _SwipeActionButton(
      {required this.child,
      required this.onTap,
      required this.label,
      this.size = 64});
  @override
  Widget build(BuildContext context) => Tooltip(
      message: label,
      child: Semantics(
          button: true,
          label: label,
          child: Material(
              color: const Color(0xFF0E0E0E),
              shape: const CircleBorder(),
              elevation: 4,
              child: InkWell(
                  onTap: onTap,
                  customBorder: const CircleBorder(),
                  child: SizedBox(
                      width: size,
                      height: size,
                      child: Center(child: child))))));
}

class _ThickXIcon extends StatelessWidget {
  final Color color;
  final double size;

  const _ThickXIcon({
    required this.color,
    this.size = 34,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Icon(Icons.close, size: size, color: color),
        Transform.translate(
          offset: const Offset(0.7, 0.7),
          child: Icon(Icons.close, size: size, color: color.withOpacity(0.9)),
        ),
      ],
    );
  }
}

class _TopIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _TopIconButton({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: icon == Icons.logout
            ? 'Logga ut'
            : icon == Icons.tune_rounded
                ? 'Upptäcktsinställningar'
                : 'Ångra senaste swipe',
        onPressed: onTap,
        style: IconButton.styleFrom(
            backgroundColor: Colors.black.withValues(alpha: .28),
            foregroundColor: Colors.white,
            minimumSize: const Size(48, 48)),
        icon: Icon(icon, size: 23),
      );
}
