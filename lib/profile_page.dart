import 'theme/zullo_palette.dart';
import 'widgets/profile_story.dart';
import 'services/profile_images.dart';
import 'dart:async';
import 'services/relation_changes.dart';
import 'services/account_session.dart';
import 'package:flutter/material.dart';
import 'models/swipe_profile.dart';

class ProfilePage extends StatefulWidget {
  final SwipeProfile profile;
  final ImageProvider Function(String)? imageProvider;

  const ProfilePage({super.key, required this.profile, this.imageProvider});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  int _photoIndex = 0;
  bool _hidden = false;
  final _generation = AccountSession.generation;
  StreamSubscription<String>? _relationChanges;

  @override
  void initState() {
    super.initState();
    _relationChanges = RelationChanges.stream.listen((other) {
      if (!mounted || _hidden || other != widget.profile.userId || !AccountSession.isCurrent(_generation)) return;
      setState(() => _hidden = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && AccountSession.isCurrent(_generation)) {
        final route = ModalRoute.of(context);
        if (route != null) {
          if (route.isCurrent) { Navigator.of(context).pop(); }
          else { Navigator.of(context).removeRoute(route); }
        }
      }
      });
    });
  }

  @override
  void dispose() {
    _relationChanges?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hidden || !AccountSession.isCurrent(_generation)) return const Scaffold(backgroundColor: Colors.black);
    final p = widget.profile;
    final photos = p.photoUrls;

    return Scaffold(
      backgroundColor: ZulloPalette.canvas,
      body: SafeArea(
        child: Stack(
          children: [
            CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 520,
                    child: Stack(
                      children: [
                        PageView.builder(
                          onPageChanged: (i) => setState(() => _photoIndex = i),
                          itemCount: photos.isEmpty ? 1 : photos.length,
                          itemBuilder: (_, i) {
                            if (photos.isEmpty) {
                              return Container(
                                color: Colors.grey.shade700,
                                child: const Center(
                                  child: Icon(Icons.person, size: 120, color: Colors.white),
                                ),
                              );
                            }
                            return Image(image: (widget.imageProvider ?? ProfileImages.card)(photos[i]), fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFFF0F2F6),
                                child: Center(child: Icon(Icons.person_outline_rounded, size: 64, color: Color(0xFF697180)))));
                          },
                        ),

                        if (photos.isNotEmpty) Positioned(bottom: 18, right: 18,
                          child: DecoratedBox(decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                            child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                              child: Text('${_photoIndex + 1} / ${photos.length}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))))),

                        // Top gradient
                        Positioned(
                          left: 0,
                          right: 0,
                          top: 0,
                          child: IgnorePointer(
                            child: Container(
                              height: 140,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black.withOpacity(0.55),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Photo bars
                        Positioned(
                          top: 10,
                          left: 12,
                          right: 12,
                          child: _PhotoBars(
                            count: photos.isEmpty ? 1 : photos.length,
                            activeIndex: _photoIndex,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 30),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "${p.displayName}, ${p.age}",
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          [p.livePlace, if (p.distanceKm > 0) "${p.distanceKm.round()} km bort"].where((s) => s.trim().isNotEmpty).join(" · "),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black.withOpacity(0.65),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        ProfileStory(profile: p),
                        const SizedBox(height: 120),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            Positioned(
              top: 10,
              left: 10,
              child: _CircleIconButton(
                icon: Icons.close,
                onTap: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoBars extends StatelessWidget {
  final int count;
  final int activeIndex;

  const _PhotoBars({required this.count, required this.activeIndex});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(count, (i) {
        final active = i == activeIndex;
        return Expanded(
          child: Container(
            height: 4,
            margin: EdgeInsets.only(right: i == count - 1 ? 0 : 6),
            decoration: BoxDecoration(
              color: active
                  ? Colors.white.withOpacity(0.95)
                  : Colors.white.withOpacity(0.35),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        );
      }),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.55),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }
}