import 'package:flutter/material.dart';
import 'models/swipe_profile.dart';

class ProfilePage extends StatefulWidget {
  final SwipeProfile profile;

  const ProfilePage({super.key, required this.profile});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  int _photoIndex = 0;

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    final photos = p.photoUrls;

    return Scaffold(
      backgroundColor: Colors.black,
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
                            return Image.network(photos[i], fit: BoxFit.cover);
                          },
                        ),

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
                          "${p.intention} • ${p.countryCode}",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black.withOpacity(0.65),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 18),

                        _InfoRow(icon: Icons.public, text: "Land: ${p.countryCode}"),
                        const SizedBox(height: 10),
                        _InfoRow(icon: Icons.favorite, text: "Intention: ${p.intention}"),

                        const SizedBox(height: 22),
                        Text(
                          "Om ${p.displayName}",
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Här lägger vi bio + intressen snart när Profile-modellen kopplas i feeden.",
                          style: TextStyle(color: Colors.black.withOpacity(0.7)),
                        ),
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

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.black.withOpacity(0.7)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: Colors.black.withOpacity(0.75),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
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