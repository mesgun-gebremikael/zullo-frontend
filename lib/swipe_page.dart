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

  const SwipePage({
    super.key,
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
                  hasUnreadMessages: hasUnreadMessages,
                  onOpenRadiusSheet: onOpenRadiusSheet,
                  onOpenMatchesPage: onOpenMatchesPage,
                  onLogout: onLogout,
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
  final bool hasUnreadMessages;
  final VoidCallback onOpenRadiusSheet;
  final VoidCallback onOpenMatchesPage;
  final VoidCallback onLogout;

  const _TopOverlayBar({
    required this.hasUnreadMessages,
    required this.onOpenRadiusSheet,
    required this.onOpenMatchesPage,
    required this.onLogout,
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
              _TopIconButton(
                icon: Icons.tune_rounded,
                onTap: onOpenRadiusSheet,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _TopTabChip(label: 'För dig', selected: true),
                      SizedBox(width: 8),
                      _TopTextTab(label: 'Duos'),
                      SizedBox(width: 8),
                      _TopTextTab(label: 'Astro'),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _TopIconButton(
                icon: Icons.chat_bubble_outline,
                onTap: onOpenMatchesPage,
                showDot: hasUnreadMessages,
              ),
              const SizedBox(width: 10),
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

        final isDraggingAny = likeProgress > 0 || nopeProgress > 0 || superProgress > 0;

        return Positioned(
          left: 0,
          right: 0,
          bottom: 18,
          child: SafeArea(
            top: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 90),
                  opacity: isDraggingAny ? 0.10 : 1.0,
                  child: _TinderCircleButton(
                    size: 52,
                    onTap: () {},
                    child: const Icon(
                      Icons.refresh_rounded,
                      size: 26,
                      color: Colors.orange,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                AnimatedScale(
                  duration: const Duration(milliseconds: 90),
                  scale: nopeProgress > 0 ? 1.22 : 1.0,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 90),
                    opacity: likeProgress > 0 || superProgress > 0 ? 0.10 : 1.0,
                    child: _TinderCircleButton(
                      size: 62,
                      onTap: onSwipeLeft,
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
                    child: _TinderCircleButton(
                      size: 54,
                      onTap: onSwipeUp,
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
                    child: _TinderCircleButton(
                      size: 62,
                      onTap: onSwipeRight,
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
                  child: _TinderCircleButton(
                    size: 52,
                    onTap: onOpenEditProfile,
                    child: const Icon(
                      Icons.send_rounded,
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

class _TinderCircleButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final double size;

  const _TinderCircleButton({
    required this.child,
    required this.onTap,
    this.size = 64,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFF0E0E0E),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              blurRadius: 16,
              spreadRadius: 0,
              color: Colors.black.withOpacity(0.28),
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Center(child: child),
      ),
    );
  }
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
  final bool showDot;

  const _TopIconButton({
    required this.icon,
    required this.onTap,
    this.showDot = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.28),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          if (showDot)
            Positioned(
              right: 2,
              top: 2,
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF2D75),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TopTabChip extends StatelessWidget {
  final String label;
  final bool selected;

  const _TopTabChip({
    required this.label,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: selected
            // 🔥 Afrikansk varm ton (subtil, inte stark)
            ? const Color(0xFF3A2A1E).withOpacity(0.72)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        border: selected
            ? Border.all(
                color: const Color(0xFFC89B3C).withOpacity(0.35),
                width: 1,
              )
            : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }
}
class _TopTextTab extends StatelessWidget {
  final String label;

  const _TopTextTab({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        color: const Color(0xFF3A2A1E).withOpacity(0.72),
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}