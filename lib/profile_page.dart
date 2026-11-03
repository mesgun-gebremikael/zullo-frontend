import 'widgets/profile_gallery.dart';
import 'theme/zullo_palette.dart';
import 'widgets/profile_story.dart';
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
  bool _hidden = false;
  final _generation = AccountSession.generation;
  StreamSubscription<String>? _relationChanges;

  @override
  void initState() {
    super.initState();
    _relationChanges = RelationChanges.stream.listen((other) {
      if (!mounted ||
          _hidden ||
          other != widget.profile.userId ||
          !AccountSession.isCurrent(_generation)) {
        return;
      }
      setState(() => _hidden = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && AccountSession.isCurrent(_generation)) {
          final route = ModalRoute.of(context);
          if (route != null) {
            if (route.isCurrent) {
              Navigator.of(context).pop();
            } else {
              Navigator.of(context).removeRoute(route);
            }
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
    if (_hidden || !AccountSession.isCurrent(_generation)) {
      return const Scaffold(backgroundColor: Colors.black);
    }
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
                    child: ProfileGallery(
                        key: ValueKey(p.userId),
                        photos: photos,
                        imageProvider: widget.imageProvider)),
                SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 30),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(26)),
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
                          [
                            p.livePlace,
                            if (p.distanceKm > 0)
                              "${p.distanceKm.round()} km bort"
                          ].where((s) => s.trim().isNotEmpty).join(" · "),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black.withValues(alpha: 0.65),
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
          color: Colors.black.withValues(alpha: 0.55),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }
}
