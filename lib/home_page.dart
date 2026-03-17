import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'services/auth_service.dart';
import 'services/auth_storage.dart';
import 'models/swipe_profile.dart';
import 'premium_page.dart';
import 'welcome_page.dart';
import 'matches_page.dart';
import 'profile_page.dart';
import 'chat_page.dart';
import 'edit_profile_page.dart';

enum SwipeDir { left, right, up }

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> 
    with SingleTickerProviderStateMixin,WidgetsBindingObserver {
  final AuthService _authService = AuthService();
  final AuthStorage _storage = AuthStorage();

  List<SwipeProfile> profiles = [];
  bool isLoading = true;
  String? error;
  int currentIndex = 0;
  bool hasUnreadMessages = false;
  String myPhotoUrl = "";
  double _radiusKm = 50;

  // ===== Drag state (Tinder swipe) =====
  Offset _drag = Offset.zero; // px
  bool _isDragging = false;

  // ===== Animation (swipe out / snap back) =====
  late final AnimationController _anim;
  Animation<Offset>? _animOffset;
  Animation<double>? _animRotate; // radians factor
  Animation<double>? _animFade;

  bool _isAnimating = false;

  @override
void initState() {
  super.initState();
  WidgetsBinding.instance.addObserver(this);
  _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  loadFeed();
  loadUnreadStatus();
  loadMyPhoto();
}

  @override
  void dispose() {
     WidgetsBinding.instance.removeObserver(this);
    _anim.dispose();
    super.dispose();
  }

  @override
   void didChangeAppLifecycleState(AppLifecycleState state) {
   if (state == AppLifecycleState.resumed) {
    loadUnreadStatus();
  }
}

  Future<void> loadFeed() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
  final data = await _authService.getSwipeFeed();
  setState(() {
    profiles = data;
    currentIndex = 0;
    isLoading = false;
    error = data.isEmpty ? "Inga profiler just nu" : null;
  });
      _precacheNextProfile();
  //_precacheNextImage(); // D HÄR
} catch (_) {
  setState(() {
    error = "Kunde inte ladda feed";
    isLoading = false;
  });
}
  }

  Future<void> loadUnreadStatus() async {
  try {
    final matchesData = await _authService.getMatches();
    final matchesList = List<dynamic>.from(matchesData);

    final hasUnread = matchesList.any((m) => m["hasUnread"] == true);

    if (!mounted) return;

    setState(() {
      hasUnreadMessages = hasUnread;
    });
  } catch (_) {
    // ignorera i MVP
  }
}

Future<void> loadMyPhoto() async {
  try {
    final me = await _authService.getMyProfile();
    final photos = (me["photoUrls"] ?? []) as List;
    if (photos.isNotEmpty && mounted) {
      setState(() {
        myPhotoUrl = photos.first.toString();
      });
    }
  } catch (_) {}
}

  void nextProfile() {
  if (!mounted) return;
  if (profiles.isEmpty) return;

  if (currentIndex < profiles.length - 1) {
    setState(() => currentIndex++);
    _precacheNextProfile();

    if (currentIndex >= profiles.length - 3) {
      loadFeed();
    }

  } else {
    loadFeed();
  }
}

  void showToast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), duration: const Duration(milliseconds: 900)),
    );
  }
Future<void> _openEditProfile() async {
  final changed = await Navigator.push<bool>(
    context,
    MaterialPageRoute(
      builder: (_) => const EditProfilePage(),
    ),
  );

  if (changed == true) {
    await loadFeed();
    await loadUnreadStatus();
  }
}

  void _precacheNextImage() {
  if (!mounted) return;
  if (profiles.isEmpty) return;

  final nextIndex = currentIndex + 1;
  if (nextIndex >= profiles.length) return;

  final next = profiles[nextIndex];
  final url = next.photoUrls.isNotEmpty ? next.photoUrls.first : "";

  if (url.startsWith("http://") || url.startsWith("https://")) {
    precacheImage(NetworkImage(url), context);
  }
}

  // ================= MATCH POPUP =================
  Future<void> showMatchPopup({required SwipeProfile other}) async {
    if (!mounted) return;

    final otherPhoto = other.photoUrls.isNotEmpty ? other.photoUrls.first : "";

     
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: Container(
  padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
  decoration: BoxDecoration(
    color: const Color(0xFF111111),
    borderRadius: BorderRadius.circular(28),
    border: Border.all(
      color: Colors.white.withOpacity(0.08),
      width: 1,
    ),
    boxShadow: [
      BoxShadow(
        blurRadius: 36,
        color: Colors.black.withOpacity(0.45),
        offset: const Offset(0, 18),
      ),
    ],
  ),
          child: Stack(
  children: [
    Positioned(
      top: 0,
      right: 0,
      child: IconButton(
        onPressed: () => Navigator.pop(ctx),
        icon: const Icon(
          Icons.close,
          color: Colors.white70,
        ),
      ),
    ),
    Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          "Det är en match!",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w900,
            color: Colors.pink.shade200,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          "Du och ${other.displayName} gillar varandra.\nSäg hej eller fortsätt swipa.",
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 15,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 28),
        _matchAvatarsRow(
          otherPhotoUrl: otherPhoto,
          myPhotoUrl: myPhotoUrl,
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);

              final otherPhoto =
                  other.photoUrls.isNotEmpty ? other.photoUrls.first : "";

              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatPage(
                    userId: other.userId,
                    displayName: other.displayName,
                    photoUrl: otherPhoto,
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: const Text("Säg hej"),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton(
            onPressed: () => Navigator.pop(ctx),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white30, width: 1.2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: const Text("Fortsätt swipa"),
          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}
   

 Widget _matchAvatarsRow({
  required String otherPhotoUrl,
  required String myPhotoUrl,
}) {
  Widget avatar(String url) {
    return Container(
      width: 112,
      height: 112,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipOval(
        child: url.isNotEmpty
            ? Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) {
                  return Container(
                    color: Colors.white10,
                    child: const Center(
                      child: Icon(Icons.person, color: Colors.white, size: 44),
                    ),
                  );
                },
              )
            : Container(
                color: Colors.white10,
                child: const Center(
                  child: Icon(Icons.person, color: Colors.white, size: 44),
                ),
              ),
      ),
    );
  }

  return SizedBox(
    height: 124,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Positioned(
          left: 8,
          child: Transform.rotate(
            angle: -0.10,
            child: avatar(myPhotoUrl),
          ),
        ),
        Positioned(
          right: 8,
          child: Transform.rotate(
            angle: 0.10,
            child: avatar(otherPhotoUrl),
          ),
        ),
        Container(
          width: 42,
          height: 42,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.favorite,
            color: Colors.red,
            size: 24,
          ),
        ),
      ],
    ),
  );
}

  // ================= Tinder Buttons =================
  Widget tinderCircleButton({
    required Widget child,
    required VoidCallback onTap,
    double size = 64,
  }) {
    return GestureDetector(
      onTap: (_isAnimating || isLoading) ? null : onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              blurRadius: 18,
              spreadRadius: 2,
              color: Colors.black.withOpacity(0.12),
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Center(child: child),
      ),
    );
  }

  Widget thickXIcon({required Color color, double size = 34}) {
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

  // ================= Swipe helpers =================
  SwipeDir? _decideDir(Size screen) {
    // Trösklar i px (känns Tinder-ish)
    const dxThreshold = 120.0;
    const upThreshold = 140.0;

    if (_drag.dx > dxThreshold) return SwipeDir.right;
    if (_drag.dx < -dxThreshold) return SwipeDir.left;
    if (_drag.dy < -upThreshold) return SwipeDir.up;
    return null;
  }

  Future<void> _animateTo(Offset end, {required double rotateEnd, required double fadeEnd}) async {
    _anim.stop();
    _anim.reset();

    final curve = CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic);

    _animOffset = Tween<Offset>(begin: _drag, end: end).animate(curve);
    _animRotate = Tween<double>(begin: _rotationForDrag(), end: rotateEnd).animate(curve);
    _animFade = Tween<double>(begin: 1.0, end: fadeEnd).animate(curve);

    setState(() => _isAnimating = true);

    await _anim.forward();

    setState(() {
      _isAnimating = false;
      _drag = Offset.zero;
      _isDragging = false;
      _animOffset = null;
      _animRotate = null;
      _animFade = null;
    });
  }

  double _rotationForDrag() {
    // Lite rotation som Tinder: max ca 10 grader
    final rot = (_drag.dx / 320.0).clamp(-0.18, 0.18);
    return rot;
  }

  Future<void> _performSwipe(SwipeDir dir) async {
    if (profiles.isEmpty || currentIndex >= profiles.length) return;
    if (_isAnimating) return;

    final p = profiles[currentIndex];

    // 1) Backend action
    if (dir == SwipeDir.left) {
      try {
        await _authService.skip(p.userId);
      } catch (_) {}
    } else {
      // right or up => like (SuperLike = like i MVP)
      try {
        final matched = await _authService.like(p.userId);
        if (matched) {
          await showMatchPopup(other: p);
        } else if (dir == SwipeDir.up) {
          showToast("Super Like skickad ⭐");
        }
      } catch (e) {
  if (e.toString().contains("429")) {
    showToast("Du har nått like-gränsen ❤️");

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const PremiumPage(),
      ),
    );

    return;
  }

  final msg = dir == SwipeDir.up
      ? "Super Like misslyckades"
      : "Like misslyckades";

  showToast(msg);
}
    }

    // 2) Animate off screen
    final size = MediaQuery.of(context).size;
    final offX = size.width * 1.2;
    final offY = size.height * 0.35;

    final end = switch (dir) {
      SwipeDir.left => Offset(-offX, 0),
      SwipeDir.right => Offset(offX, 0),
      SwipeDir.up => Offset(0, -offY),
    };

    final rotEnd = switch (dir) {
      SwipeDir.left => -0.18,
      SwipeDir.right => 0.18,
      SwipeDir.up => 0.0,
    };

    await _animateTo(end, rotateEnd: rotEnd, fadeEnd: 0.0);

    // 3) Next card
    nextProfile();
  }

  Future<void> _snapBack() async {
    await _animateTo(Offset.zero, rotateEnd: 0.0, fadeEnd: 1.0);
  }

  void _precacheNextProfile() {
  if (profiles.isEmpty) return;

  final nextIndex = currentIndex + 1;
  if (nextIndex >= profiles.length) return;

  final nextProfile = profiles[nextIndex];

  if (nextProfile.photoUrls.isEmpty) return;

  precacheImage(
    NetworkImage(nextProfile.photoUrls.first),
    context,
  );
}

Future<void> _openRadiusSheet() async {
  double tempRadius = _radiusKm;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Avstånd',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${tempRadius.round()} km',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Slider(
                  value: tempRadius,
                  min: 1,
                  max: 200,
                  divisions: 199,
                  label: '${tempRadius.round()} km',
                  onChanged: (value) {
                    setModalState(() {
                      tempRadius = value;
                    });
                  },
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context);

                      try {
                        final savedKm =
                            await _authService.updateRadius(tempRadius.round());

                        setState(() {
                          _radiusKm = savedKm.toDouble();
                          currentIndex = 0;
                        });

                        await loadFeed();
                        showToast('Avstånd uppdaterat till ${savedKm} km');
                      } catch (e) {
                        showToast('Kunde inte uppdatera avstånd');
                      }
                    },
                    child: const Text('Spara'),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    final hasProfile = profiles.isNotEmpty && currentIndex < profiles.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Zullo"),
        actions: [
          IconButton(
  icon: const Icon(Icons.edit_outlined),
  onPressed: _openEditProfile,
),

 IconButton(
    icon: const Icon(Icons.tune),
    onPressed: _openRadiusSheet,
  ),
   
          IconButton(
  icon: Stack(
    clipBehavior: Clip.none,
    children: [
      const Icon(Icons.chat_bubble_outline),
      if (hasUnreadMessages)
        Positioned(
          right: -1,
          top: -1,
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
          ),
        ),
    ],
  ),
  onPressed: () async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MatchesPage()),
    );

    if (!mounted) return;
    await loadUnreadStatus();
  },
),
         IconButton(
  icon: const Icon(Icons.logout),
  onPressed: () async {
    await _storage.clearAuth(); // ✅ rensar token + userId
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const WelcomePage()),
      (_) => false,
    );
  },
),
        ],
      ),
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : error != null
                ? Center(child: Text(error!))
                : !hasProfile
                    ? const Center(child: Text("Inga profiler just nu"))
                    : _buildTinderLayout(profiles[currentIndex]),
      ),
    );
  }

  Widget _buildTinderLayout(SwipeProfile p) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth;
        final cardHeight = constraints.maxHeight;

        final activeOffset = _animOffset?.value ?? _drag;
        final activeRot = _animRotate?.value ?? _rotationForDrag();
        final activeFade = _animFade?.value ?? 1.0;

        return Stack(
          children: [
            // Card (draggable)
            Center(
              child: GestureDetector(
                onPanStart: (_) {
                  if (_isAnimating) return;
                  setState(() => _isDragging = true);
                },
                onPanUpdate: (d) {
                  if (_isAnimating) return;
                  setState(() {
                    _drag += d.delta;
                  });
                },
                onPanEnd: (_) async {
                  if (_isAnimating) return;
                  setState(() => _isDragging = false);

                  final dir = _decideDir(MediaQuery.of(context).size);
                  if (dir == null) {
                    await _snapBack();
                  } else {
                    await _performSwipe(dir);
                  }
                },
                child: Opacity(
                  opacity: activeFade,
                  child: Transform.translate(
                    offset: activeOffset,
                    child: Transform.rotate(
                      angle: activeRot,
                     child: GestureDetector(
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProfilePage(profile: p)),
    );
  },
  child: _TinderCard(profile: p, width: cardWidth, height: cardHeight),
),
                    ),
                  ),
                ),
              ),
            ),

            // Bottom action bar (Tinder style)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    tinderCircleButton(
                      size: 74,
                      onTap: () => _performSwipe(SwipeDir.left),
                      child: thickXIcon(color: Colors.red, size: 36),
                    ),
                    tinderCircleButton(
                      size: 62,
                      onTap: () => _performSwipe(SwipeDir.up), // SuperLike (MVP like)
                      child: const Icon(Icons.star, size: 30, color: Colors.blue),
                    ),
                    tinderCircleButton(
                      size: 74,
                      onTap: () => _performSwipe(SwipeDir.right),
                      child: const Icon(Icons.favorite, size: 36, color: Colors.green),
                    ),
                  ],
                ),
              ),
            ),

            // Tiny hint overlay (bara när man drar)
            if (_isDragging && !_isAnimating)
              Positioned(
                top: 18,
                left: 18,
                child: _SwipeHint(drag: _drag),
              ),
          ],
        );
      },
    );
  }
}

class _TinderCard extends StatefulWidget {
  final SwipeProfile profile;
  final double width;
  final double height;

  const _TinderCard({
    required this.profile,
    required this.width,
    required this.height,
  });

  @override
  State<_TinderCard> createState() => _TinderCardState();
}

class _TinderCardState extends State<_TinderCard> {
  int imageIndex = 0;

  @override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _precacheNextPhoto();
  });
}

void _precacheNextPhoto() {
  final profile = widget.profile;

  if (profile.photoUrls.isEmpty) return;

  final nextIndex = imageIndex + 1;
  if (nextIndex >= profile.photoUrls.length) return;

  precacheImage(
    NetworkImage(profile.photoUrls[nextIndex]),
    context,
  );
}

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final width = widget.width;
    final height = widget.height;

    final cardHeight = height - 110;
    final photoUrl =
        profile.photoUrls.isNotEmpty ? profile.photoUrls[imageIndex] : "";

    return Container(
      width: math.min(420, width * 0.96),
      height: cardHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            offset: const Offset(0, 8),
            color: Colors.black.withOpacity(0.18),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Photo
            // Photo
GestureDetector(
  onTapUp: (details) {
    if (profile.photoUrls.length <= 1) return;

    final cardWidth = widget.width;
    final tapX = details.localPosition.dx;

    setState(() {
  if (tapX > cardWidth / 2) {
    if (imageIndex < profile.photoUrls.length - 1) {
      imageIndex++;
    }
  } else {
    if (imageIndex > 0) {
      imageIndex--;
    }
  }
});

_precacheNextPhoto();
  },
  child: profile.photoUrls.isNotEmpty
      ? Image.network(
          profile.photoUrls[imageIndex],
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) {
            return Container(
              color: Colors.grey.shade400,
              child: const Center(
                child: Icon(Icons.person, size: 120, color: Colors.white),
              ),
            );
          },
        )
      : Container(
          color: Colors.grey.shade400,
          child: const Center(
            child: Icon(Icons.person, size: 120, color: Colors.white),
          ),
        ),
),

    Positioned(
  top: 12,
  left: 12,
  right: 12,
  child: Row(
    children: List.generate(profile.photoUrls.length, (index) {
      final isActive = index == imageIndex;

      return Expanded(
        child: Container(
          height: 4,
          margin: EdgeInsets.only(
            right: index == profile.photoUrls.length - 1 ? 0 : 4,
          ),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.white38,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      );
    }),
  ),
),

            // Gradient bottom like Tinder
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 170,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.0),
                      Colors.black.withOpacity(0.65),
                    ],
                  ),
                ),
              ),
            ),

            // Text overlay
            Positioned(
              left: 18,
              right: 18,
              bottom: 18,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "${profile.displayName}, ${profile.age}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "${profile.intention} • ${profile.countryCode}",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.88),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SwipeHint extends StatelessWidget {
  final Offset drag;
  const _SwipeHint({required this.drag});

  @override
  Widget build(BuildContext context) {
    final dirText = () {
      if (drag.dx > 120) return "LIKE";
      if (drag.dx < -120) return "NOPE";
      if (drag.dy < -140) return "SUPER LIKE";
      return "";
    }();

    if (dirText.isEmpty) return const SizedBox.shrink();

    final color = dirText == "NOPE"
        ? Colors.red
        : (dirText == "LIKE" ? Colors.green : Colors.blue);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 3),
        borderRadius: BorderRadius.circular(10),
        color: Colors.transparent,
      ),
      child: Text(
        dirText,
        style: TextStyle(
          color: color,
          fontSize: 20,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}