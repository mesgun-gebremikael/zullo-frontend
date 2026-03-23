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
import 'swipe_page.dart';

enum SwipeDir { left, right, up }

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final AuthService _authService = AuthService();
  final AuthStorage _storage = AuthStorage();

  List<SwipeProfile> profiles = [];
  bool isLoading = true;
  String? error;
  int currentIndex = 0;
  bool hasUnreadMessages = false;
  String myPhotoUrl = "";
  double _radiusKm = 50;

  String _selectedIntention = 'Relationship';
  String _selectedReligion = 'Private';
  int _minAge = 18;
  int _maxAge = 99;

    Offset _drag = Offset.zero;
  bool _isDragging = false;

  final ValueNotifier<Offset> _dragNotifier = ValueNotifier(Offset.zero);
  final ValueNotifier<bool> _isDraggingNotifier = ValueNotifier(false);

  late final AnimationController _anim;
  Animation<Offset>? _animOffset;
  Animation<double>? _animRotate;
  Animation<double>? _animFade;

  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    loadFeed();
    loadUnreadStatus();
    loadMyPhoto();
    _loadMyFilterValues();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dragNotifier.dispose();
    _isDraggingNotifier.dispose();
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
      final data = await _authService.getSwipeFeed(
        minAge: _minAge,
        maxAge: _maxAge,
      );

      final loadedProfiles = List<SwipeProfile>.from(data['profiles']);
      final loadedRadius = (data['radiusKm'] as num).toDouble();

      setState(() {
        profiles = loadedProfiles;
        _radiusKm = loadedRadius;
        currentIndex = 0;
        isLoading = false;
        error = loadedProfiles.isEmpty ? "Inga profiler just nu" : null;
      });

      _precacheNextProfile();
    } catch (e) {
      debugPrint('LOAD FEED ERROR: $e');

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
    } catch (_) {}
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
      SnackBar(
        content: Text(text),
        duration: const Duration(milliseconds: 900),
      ),
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

  SwipeDir? _decideDir(Size screen) {
    const dxThreshold = 100.0;
    const upThreshold = 150.0;

    if (_drag.dx > dxThreshold) return SwipeDir.right;
    if (_drag.dx < -dxThreshold) return SwipeDir.left;
    if (_drag.dy < -upThreshold && _drag.dy.abs() > _drag.dx.abs() * 0.9) {
      return SwipeDir.up;
    }
    return null;
  }

  Future<void> _animateTo(
    Offset end, {
    required double rotateEnd,
    required double fadeEnd,
  }) async {
    _anim.stop();
    _anim.reset();

    final curve = CurvedAnimation(parent: _anim, curve: Curves.easeOutQuart);

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

    _dragNotifier.value = Offset.zero;
    _isDraggingNotifier.value = false;
  }

  double _rotationForDrag() {
    final rot = (_drag.dx / 520.0).clamp(-0.11, 0.11);
    return rot;
  }

  double _likeProgress() {
    return (_drag.dx / 140).clamp(0.0, 1.0).toDouble();
  }

  double _nopeProgress() {
    return (-_drag.dx / 140).clamp(0.0, 1.0).toDouble();
  }

  double _superProgress() {
    final raw = (-_drag.dy / 170).clamp(0.0, 1.0).toDouble();
    if (_drag.dy >= 0) return 0.0;
    if (_drag.dy.abs() < _drag.dx.abs() * 0.55) return 0.0;
    return raw;
  }

  Future<void> _performSwipe(SwipeDir dir) async {
    if (profiles.isEmpty || currentIndex >= profiles.length) return;
    if (_isAnimating) return;

    final p = profiles[currentIndex];

    if (dir == SwipeDir.left) {
      try {
        await _authService.skip(p.userId);
      } catch (_) {}
    } else {
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

    final size = MediaQuery.of(context).size;
    final offX = size.width * 1.15;
    final offY = size.height * 0.34;

    final end = switch (dir) {
      SwipeDir.left => Offset(-offX, -offY * 0.35),
      SwipeDir.right => Offset(offX, -offY * 0.35),
      SwipeDir.up => Offset(0, -offY * 1.08),
    };

    final rotEnd = switch (dir) {
      SwipeDir.left => -0.17,
      SwipeDir.right => 0.17,
      SwipeDir.up => 0.0,
    };

    await _animateTo(end, rotateEnd: rotEnd, fadeEnd: 0.0);

    nextProfile();
  }

  Future<void> _snapBack() async {
    await _animateTo(Offset.zero, rotateEnd: 0.0, fadeEnd: 1.0);
  }

    void _precacheNextProfile() {
    if (!mounted || profiles.isEmpty) return;

    final startIndex = currentIndex + 1;
    final endIndex = (currentIndex + 3 < profiles.length)
        ? currentIndex + 3
        : profiles.length - 1;

    for (int i = startIndex; i <= endIndex; i++) {
      final profile = profiles[i];
      if (profile.photoUrls.isEmpty) continue;

      for (final url in profile.photoUrls.take(2)) {
        precacheImage(
          NetworkImage(url),
          context,
        );
      }
    }
  }

  Future<void> _loadMyFilterValues() async {
    try {
      final me = await _authService.getMyProfile();

      setState(() {
        _selectedIntention = (me["intention"] ?? "Relationship").toString();
        _selectedReligion = (me["religion"] ?? "Private").toString();
      });
    } catch (_) {}
  }

  Future<void> _openRadiusSheet() async {
    double tempRadius = _radiusKm;
    String tempIntention = _selectedIntention;
    String tempReligion = _selectedReligion;
    int tempMinAge = _minAge;
    int tempMaxAge = _maxAge;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF4F4F5),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.black12,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Inställningar',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1D1D1F),
                              ),
                            ),
                          ),
                          Container(
                            width: 54,
                            height: 54,
                            decoration: const BoxDecoration(
                              color: Color(0xFF101826),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              onPressed: () async {
                                Navigator.pop(context);

                                try {
                                  final savedKm =
                                      await _authService.updateRadius(tempRadius.round());

                                  await _authService.updateFilterProfile(
                                    intention: tempIntention,
                                    religion: tempReligion,
                                  );

                                  setState(() {
                                    _radiusKm = savedKm.toDouble();
                                    _selectedIntention = tempIntention;
                                    _selectedReligion = tempReligion;
                                    _minAge = tempMinAge;
                                    _maxAge = tempMaxAge;
                                    currentIndex = 0;
                                  });

                                  await loadFeed();
                                  showToast('Filter uppdaterade');
                                } catch (_) {
                                  showToast('Kunde inte uppdatera filter');
                                }
                              },
                              icon: const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 30,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'DISCOVERY',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF66707F),
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Plats',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF22252B),
                              ),
                            ),
                            const SizedBox(height: 14),
                            const Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Din plats här senare',
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: Color(0xFF596170),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  size: 34,
                                  color: Color(0xFF8E96A3),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Ändra plats för att swipa någon annanstans.',
                              style: TextStyle(
                                fontSize: 16,
                                height: 1.3,
                                color: Color(0xFF596170),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Divider(color: Colors.black.withOpacity(0.08), height: 1),
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Maxavstånd',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF22252B),
                                    ),
                                  ),
                                ),
                                Text(
                                  '${tempRadius.round()} km',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    color: Color(0xFF596170),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 3,
                                activeTrackColor: const Color(0xFFFF2D75),
                                inactiveTrackColor: const Color(0xFF8F97A3),
                                thumbColor: Colors.white,
                                overlayColor: Colors.transparent,
                                thumbShape:
                                    const RoundSliderThumbShape(enabledThumbRadius: 18),
                              ),
                              child: Slider(
                                value: tempRadius,
                                min: 1,
                                max: 200,
                                divisions: 199,
                                onChanged: (value) {
                                  setModalState(() {
                                    tempRadius = value;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Visa personer längre bort om det inte finns fler profiler att se.',
                                    style: TextStyle(
                                      fontSize: 16,
                                      height: 1.3,
                                      color: Color(0xFF596170),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Transform.scale(
                                  scale: 1.15,
                                  child: Switch(
                                    value: true,
                                    onChanged: (_) {},
                                    activeColor: Colors.white,
                                    activeTrackColor: const Color(0xFFFF2D75),
                                    inactiveThumbColor: Colors.white,
                                    inactiveTrackColor: const Color(0xFFD1D1D6),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Divider(color: Colors.black.withOpacity(0.08), height: 1),
                            const SizedBox(height: 18),
                            const Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Intresserad av',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF22252B),
                                    ),
                                  ),
                                ),
                                Text(
                                  'Kvinnor',
                                  style: TextStyle(
                                    fontSize: 22,
                                    color: Color(0xFF596170),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  size: 30,
                                  color: Color(0xFF8E96A3),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            Divider(color: Colors.black.withOpacity(0.08), height: 1),
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Åldersspann',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF22252B),
                                    ),
                                  ),
                                ),
                                Text(
                                  '$tempMinAge-$tempMaxAge',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    color: Color(0xFF596170),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: const Color(0xFFFF2D75),
                                inactiveTrackColor: const Color(0xFF8F97A3),
                                thumbColor: Colors.white,
                                overlayColor: Colors.transparent,
                                trackHeight: 3,
                                rangeThumbShape: const RoundRangeSliderThumbShape(
                                  enabledThumbRadius: 18,
                                ),
                              ),
                              child: RangeSlider(
                                values: RangeValues(
                                  tempMinAge.toDouble(),
                                  tempMaxAge.toDouble(),
                                ),
                                min: 18,
                                max: 100,
                                divisions: 82,
                                onChanged: (values) {
                                  setModalState(() {
                                    tempMinAge = values.start.round();
                                    tempMaxAge = values.end.round();
                                  });
                                },
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Visa personer lite utanför det intervall jag föredrar om det inte finns fler profiler att se',
                                    style: TextStyle(
                                      fontSize: 16,
                                      height: 1.3,
                                      color: Color(0xFF596170),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Transform.scale(
                                  scale: 1.15,
                                  child: Switch(
                                    value: true,
                                    onChanged: (_) {},
                                    activeColor: Colors.white,
                                    activeTrackColor: const Color(0xFFFF2D75),
                                    inactiveThumbColor: Colors.white,
                                    inactiveTrackColor: const Color(0xFFD1D1D6),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            Divider(color: Colors.black.withOpacity(0.08), height: 1),
                            const SizedBox(height: 18),
                            const Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Globalt läge',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF22252B),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 52,
                                  child: Switch(
                                    value: false,
                                    onChanged: null,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          'Med Globalt läge får du upp människor i närheten och över hela världen.',
                          style: TextStyle(
                            fontSize: 16,
                            height: 1.35,
                            color: Color(0xFF596170),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openMatchesPage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MatchesPage()),
    );

    if (!mounted) return;
    await loadUnreadStatus();
  }

  Future<void> _logout() async {
    await _storage.clearAuth();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const WelcomePage()),
      (_) => false,
    );
  }

  Widget _buildEmptyFeedState() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 120, 20, 40),
      child: Center(
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          decoration: BoxDecoration(
            color: const Color(0xFF111111),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.travel_explore_rounded,
                color: Colors.white,
                size: 54,
              ),
              const SizedBox(height: 16),
              const Text(
                "Inga profiler just nu",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Testa att öka avståndet eller ändra åldersspannet i filtret.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.72),
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _openRadiusSheet,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF2D75),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: const Text("Öppna filter"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

    @override
  Widget build(BuildContext context) {
    final hasProfile = profiles.isNotEmpty && currentIndex < profiles.length;
    final currentProfile = hasProfile ? profiles[currentIndex] : null;

    SwipeProfile? nextProfile;
    if (hasProfile && currentIndex + 1 < profiles.length) {
      nextProfile = profiles[currentIndex + 1];
    }

       return SwipePage(
      isLoading: isLoading,
      hasActiveProfile: currentProfile != null,
      hasUnreadMessages: hasUnreadMessages,
      dragListenable: _dragNotifier,
      onOpenRadiusSheet: _openRadiusSheet,
      onOpenMatchesPage: _openMatchesPage,
      onLogout: _logout,
      onOpenEditProfile: _openEditProfile,
      onSwipeLeft: () {
        if (!_isAnimating && !isLoading) {
          _performSwipe(SwipeDir.left);
        }
      },
      onSwipeUp: () {
        if (!_isAnimating && !isLoading) {
          _performSwipe(SwipeDir.up);
        }
      },
      onSwipeRight: () {
        if (!_isAnimating && !isLoading) {
          _performSwipe(SwipeDir.right);
        }
      },
      nextCard: nextProfile != null ? _buildNextCard(nextProfile) : null,
      activeCard: currentProfile != null
          ? _buildActiveCard(currentProfile)
          : const SizedBox.shrink(),
      emptyState: _buildEmptyFeedState(),
    );
  }

     Widget _buildNextCard(SwipeProfile nextProfile) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth;
        final cardHeight = constraints.maxHeight;

        return Center(
          child: Transform.translate(
            offset: const Offset(0, 40),
            child: Transform.scale(
              scale: 0.93,
              child: Opacity(
                opacity: 0.82,
                child: IgnorePointer(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(34),
                    child: SizedBox(
                      width: cardWidth,
                      height: cardHeight - 28,
                      child: ColorFiltered(
                        colorFilter: ColorFilter.mode(
                          Colors.black.withOpacity(0.12),
                          BlendMode.darken,
                        ),
                        child: RepaintBoundary(
                          child: _TinderCard(
                            profile: nextProfile,
                            width: cardWidth,
                            height: cardHeight,
                            photoBarsTop: 66,
                            distanceFallbackKm: _radiusKm,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

   Widget _buildActiveCard(SwipeProfile p) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth;
        final cardHeight = constraints.maxHeight;

        return ValueListenableBuilder<Offset>(
          valueListenable: _dragNotifier,
          builder: (context, dragValue, _) {
            return ValueListenableBuilder<bool>(
              valueListenable: _isDraggingNotifier,
              builder: (context, draggingValue, __) {
                final activeOffset = _animOffset?.value ?? dragValue;
                final activeRot = _animRotate?.value ?? (dragValue.dx / 520.0).clamp(-0.11, 0.11);
                final activeFade = _animFade?.value ?? 1.0;

                return GestureDetector(
                  onPanStart: (_) {
                    if (_isAnimating) return;

                    _isDragging = true;
                    _isDraggingNotifier.value = true;
                  },
                  onPanUpdate: (d) {
                    if (_isAnimating) return;

                    _drag += Offset(d.delta.dx * 0.92, d.delta.dy * 0.88);
                    _dragNotifier.value = _drag;
                  },
                  onPanEnd: (_) async {
                    if (_isAnimating) return;

                    _isDragging = false;
                    _isDraggingNotifier.value = false;

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
                        alignment: Alignment.topCenter,
                        angle: activeRot.toDouble(),
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ProfilePage(profile: p),
                              ),
                            );
                          },
                          child: RepaintBoundary(
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                _TinderCard(
                                  profile: p,
                                  width: cardWidth,
                                  height: cardHeight,
                                  photoBarsTop: 66,
                                  distanceFallbackKm: _radiusKm,
                                ),
                                if (draggingValue && !_isAnimating)
                                  _CardSwipeStamp(drag: dragValue),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

}

class _TinderCard extends StatefulWidget {
  final SwipeProfile profile;
  final double width;
  final double height;
  final double photoBarsTop;
  final double distanceFallbackKm;

  const _TinderCard({
    required this.profile,
    required this.width,
    required this.height,
    this.photoBarsTop = 66,
    this.distanceFallbackKm = 50,
  });

  @override
  State<_TinderCard> createState() => _TinderCardState();
}

class _TinderCardState extends State<_TinderCard> {
  int imageIndex = 0;

  late String _visibleImageUrl;
  bool _isImageReady = false;

  ImageStream? _imageStream;
  ImageStreamListener? _imageListener;

  @override
  void initState() {
    super.initState();

    _visibleImageUrl = _currentPhotoUrl();
    _resolveVisibleImage(_visibleImageUrl);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _precacheAllPhotos();
      _precacheNextPhoto();
    });
  }

  @override
  void didUpdateWidget(covariant _TinderCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.profile.userId != widget.profile.userId) {
      imageIndex = 0;

      final newUrl = _currentPhotoUrl();
      _resolveVisibleImage(newUrl);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _precacheAllPhotos();
        _precacheNextPhoto();
      });
    }
  }

  @override
  void dispose() {
    _removeImageListener();
    super.dispose();
  }

  String _currentPhotoUrl() {
    final photos = widget.profile.photoUrls;
    if (photos.isEmpty) return '';

    if (imageIndex < 0 || imageIndex >= photos.length) {
      return photos.first;
    }

    return photos[imageIndex];
  }

  void _removeImageListener() {
    if (_imageStream != null && _imageListener != null) {
      _imageStream!.removeListener(_imageListener!);
    }

    _imageStream = null;
    _imageListener = null;
  }

  void _resolveVisibleImage(String url) {
    if (url.isEmpty) {
      setState(() {
        _visibleImageUrl = '';
        _isImageReady = true;
      });
      return;
    }

    final provider = NetworkImage(url);
    final stream = provider.resolve(const ImageConfiguration());

    _removeImageListener();

    _imageStream = stream;
    _imageListener = ImageStreamListener(
      (ImageInfo _, bool __) {
        if (!mounted) return;

        setState(() {
          _visibleImageUrl = url;
          _isImageReady = true;
        });

        _removeImageListener();
      },
      onError: (dynamic _, StackTrace? __) {
        if (!mounted) return;

        setState(() {
          _visibleImageUrl = url;
          _isImageReady = true;
        });

        _removeImageListener();
      },
    );

    setState(() {
      _isImageReady = false;
    });

    stream.addListener(_imageListener!);
  }

  void _changeImage(int newIndex) {
    final photos = widget.profile.photoUrls;

    if (photos.isEmpty) return;
    if (newIndex < 0 || newIndex >= photos.length) return;
    if (newIndex == imageIndex) return;

    setState(() {
      imageIndex = newIndex;
    });

    _resolveVisibleImage(photos[newIndex]);
    _precacheNextPhoto();
  }

  void _precacheAllPhotos() {
    final profile = widget.profile;

    if (profile.photoUrls.isEmpty) return;

    for (final url in profile.photoUrls.take(4)) {
      precacheImage(
        NetworkImage(url),
        context,
      );
    }
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
    final cardHeight = height - 8;

    return Container(
      width: width,
      height: cardHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            offset: const Offset(0, 8),
            color: Colors.black.withOpacity(0.22),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(34),
        child: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              onTapUp: (details) {
                if (profile.photoUrls.length <= 1) return;

                final tapX = details.localPosition.dx;

                if (tapX > width / 2) {
                  if (imageIndex < profile.photoUrls.length - 1) {
                    _changeImage(imageIndex + 1);
                  }
                } else {
                  if (imageIndex > 0) {
                    _changeImage(imageIndex - 1);
                  }
                }
              },
              child: profile.photoUrls.isNotEmpty
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        if (_visibleImageUrl.isNotEmpty)
                          Image.network(
                            _visibleImageUrl,
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                            errorBuilder: (_, __, ___) {
                              return Container(
                                color: const Color(0xFF2A2A2A),
                                child: const Center(
                                  child: Icon(
                                    Icons.person,
                                    size: 120,
                                    color: Colors.white,
                                  ),
                                ),
                              );
                            },
                          )
                        else
                          Container(
                            color: Colors.grey.shade400,
                            child: const Center(
                              child: Icon(
                                Icons.person,
                                size: 120,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        if (!_isImageReady)
                          Container(
                            color: Colors.transparent,
                          ),
                      ],
                    )
                  : Container(
                      color: Colors.grey.shade400,
                      child: const Center(
                        child: Icon(Icons.person, size: 120, color: Colors.white),
                      ),
                    ),
            ),

            Positioned(
              top: widget.photoBarsTop,
              left: 16,
              right: 16,
              child: Row(
                children: List.generate(profile.photoUrls.length, (index) {
                  final isActive = index == imageIndex;

                  return Expanded(
                    child: Container(
                      height: 2.4,
                      margin: EdgeInsets.only(
                        right: index == profile.photoUrls.length - 1 ? 0 : 4,
                      ),
                      decoration: BoxDecoration(
                        color: isActive ? Colors.white : Colors.white.withOpacity(0.28),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  );
                }),
              ),
            ),

            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: 170,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.28),
                      Colors.black.withOpacity(0.10),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 250,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.0),
                      Colors.black.withOpacity(0.18),
                      Colors.black.withOpacity(0.82),
                    ],
                  ),
                ),
              ),
            ),

            _buildBottomContent(profile),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomContent(SwipeProfile profile) {
    switch (imageIndex) {
      case 0:
        return _buildImage0(profile);
      case 1:
        return _buildImage1(profile);
      case 2:
        return _buildImage2(profile);
      case 3:
        return _buildImage3(profile);
      default:
        return _buildImage0(profile);
    }
  }

  Widget _buildImage0(SwipeProfile profile) {
    return Stack(
      children: [
        Positioned(
          left: 20,
          right: 20,
          bottom: 126,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  "${profile.displayName} ${profile.age}",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    height: 1.0,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.42),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24),
                ),
                child: const Icon(
                  Icons.arrow_upward_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: 20,
          right: 20,
          bottom: 66,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoRow(
                icon: Icons.location_on_outlined,
                text: "${profile.distanceKm.round()} km bort",
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImage1(SwipeProfile profile) {
    return Stack(
      children: [
        Positioned(
          left: 20,
          right: 20,
          bottom: 154,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  "${profile.displayName} ${profile.age}",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    height: 1.0,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.42),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24),
                ),
                child: const Icon(
                  Icons.arrow_upward_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: 20,
          right: 20,
          bottom: 84,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle(
                icon: Icons.interests_outlined,
                title: "Intressen",
              ),
              const SizedBox(height: 10),
              _chipWrap(
                profile.interests.isNotEmpty ? profile.interests : ["Musik", "Resor"],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImage2(SwipeProfile profile) {
    final lifeChips = <String>[
      if (profile.pets.isNotEmpty) profile.pets,
      if (profile.smoking.isNotEmpty) profile.smoking,
      if (profile.workout.isNotEmpty) profile.workout,
      if (profile.religion.isNotEmpty) profile.religion,
    ];

    return Stack(
      children: [
        Positioned(
          left: 20,
          right: 20,
          bottom: 162,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  "${profile.displayName} ${profile.age}",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    height: 1.0,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.42),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24),
                ),
                child: const Icon(
                  Icons.arrow_upward_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: 20,
          right: 20,
          bottom: 88,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle(
                icon: Icons.local_offer_outlined,
                title: "Om mig & Livsstil",
              ),
              const SizedBox(height: 10),
              _chipWrap(lifeChips.isNotEmpty ? lifeChips : ["Private", "No", "Sometimes"]),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImage3(SwipeProfile profile) {
    return Stack(
      children: [
        Positioned(
          left: 20,
          right: 20,
          bottom: 170,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  "${profile.displayName} ${profile.age}",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    height: 1.0,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.42),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24),
                ),
                child: const Icon(
                  Icons.arrow_upward_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: 20,
          right: 20,
          bottom: 88,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle(
                icon: Icons.search_rounded,
                title: "Söker efter",
              ),
              const SizedBox(height: 8),
              Text(
                _formatIntention(profile.intention),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
              if (profile.bio.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  profile.bio,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.92),
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle({required IconData icon, required String title}) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: Colors.white.withOpacity(0.96),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withOpacity(0.96),
              fontSize: 16,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
        ),
      ],
    );
  }

  Widget _infoRow({required IconData icon, required String text}) {
    return Row(
      children: [
        Icon(
          icon,
          size: 19,
          color: Colors.white.withOpacity(0.96),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withOpacity(0.96),
              fontSize: 16,
              fontWeight: FontWeight.w600,
              height: 1.15,
            ),
          ),
        ),
      ],
    );
  }

  Widget _chipWrap(List<String> items) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.take(6).map((item) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.68),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            item,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1.0,
            ),
          ),
        );
      }).toList(),
    );
  }

  String _formatIntention(String value) {
    switch (value) {
      case 'Relationship':
        return 'Seriöst förhållande';
      case 'Marriage':
        return 'Öppen för äktenskap';
      case 'Date':
        return 'Öppen för att dejta';
      default:
        return value.isEmpty ? 'Seriöst förhållande' : value;
    }
  }
}

class _CardSwipeStamp extends StatelessWidget {
  final Offset drag;

  const _CardSwipeStamp({required this.drag});

  @override
  Widget build(BuildContext context) {
    final likeOpacity = (drag.dx / 140).clamp(0.0, 1.0).toDouble();
    final nopeOpacity = (-drag.dx / 140).clamp(0.0, 1.0).toDouble();

    double superOpacity = (-drag.dy / 170).clamp(0.0, 1.0).toDouble();
    if (drag.dy >= 0) superOpacity = 0.0;
    if (drag.dy.abs() < drag.dx.abs() * 0.55) superOpacity = 0.0;

    if (likeOpacity <= 0 && nopeOpacity <= 0 && superOpacity <= 0) {
      return const SizedBox.shrink();
    }

    final showSuper = superOpacity > likeOpacity && superOpacity > nopeOpacity;

    return IgnorePointer(
      child: Stack(
        children: [
          if (likeOpacity > 0 && !showSuper)
            Positioned(
              top: 118,
              left: 28,
              child: Opacity(
                opacity: likeOpacity,
                child: Transform.rotate(
                  angle: -0.18,
                  child: const Icon(
                    Icons.favorite,
                    size: 108,
                    color: Color(0xFF8BE63F),
                  ),
                ),
              ),
            ),

          if (nopeOpacity > 0 && !showSuper)
            Positioned(
              top: 118,
              right: 28,
              child: Opacity(
                opacity: nopeOpacity,
                child: Transform.rotate(
                  angle: 0.18,
                  child: const Icon(
                    Icons.close_rounded,
                    size: 114,
                    color: Color(0xFFFF2D75),
                  ),
                ),
              ),
            ),

          if (showSuper)
            Positioned(
              top: 108,
              left: 0,
              right: 0,
              child: Center(
                child: Opacity(
                  opacity: superOpacity,
                  child: const Icon(
                    Icons.star_rounded,
                    size: 102,
                    color: Colors.blue,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

