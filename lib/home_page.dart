import 'services/profile_images.dart';
import 'account_management_page.dart';
import 'widgets/discovery_settings_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/commerce_service.dart';
import 'services/relation_changes.dart';
import 'dart:async';
import 'services/account_session.dart';
import 'package:flutter/material.dart';
import 'services/auth_service.dart';
import 'models/swipe_profile.dart';
import 'premium_page.dart';
import 'welcome_page.dart';
import 'matches_page.dart';
import 'profile_page.dart';
import 'chat_page.dart';
import 'edit_profile_page.dart';
import 'swipe_page.dart';
import 'widgets/swipe_profile_card.dart';

enum SwipeDir { left, right, up }

class HomePage extends StatefulWidget {
  final bool active;
  final AuthService? authService;
  const HomePage({super.key, this.active = true, this.authService});

  @override
  State<HomePage> createState() => _HomePageState();
}
class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AuthService _authService = widget.authService ?? AuthService();
  final int _sessionGeneration = AccountSession.generation;
  Timer? _emptyFeedTimer;
  StreamSubscription<String>? _relationChanges;
  StreamSubscription<void>? _commerceEvents;
  int _feedRevision = 0;
  bool _feedRequestRunning = false;
  bool _rewindInFlight = false;
  bool _feedReloadPending = false;
  bool _foreground = true;
  bool _isPaused = false;

  void _refreshEmptyFeed() {
    if (!mounted || !widget.active || !_foreground || _feedRequestRunning ||
        !AccountSession.isCurrent(_sessionGeneration) || error == 'Kunde inte ladda feed') { return; }
    if (currentIndex >= profiles.length) unawaited(loadFeed(background: true));
  }

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) _refreshEmptyFeed();
  }
 
  
  List<SwipeProfile> profiles = [];
 List<SwipeProfile> _prefetchedProfiles = [];
bool _isPrefetching = false;

  static const double _cardCornerRadius = 34;
static const double _nextCardScale = 1.0;
static const double _nextCardOffsetY = 0;
static const double _nextCardOpacity = 0.55;
static const double _activeCardLift = 0;
  bool isLoading = true;
  String? error;
  int currentIndex = 0;
  bool hasUnreadMessages = false;
  String myPhotoUrl = "";
  double _radiusKm = 50;
  String _selectedIntention = 'Relationship';
  String _selectedReligion = 'Private';
  String _interestedIn = 'Alla';
  String? _preferenceUserId;
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
  Widget? _cachedNextCard;
  String? _cachedNextCardUserId;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _emptyFeedTimer = Timer.periodic(const Duration(seconds: 20), (_) => _refreshEmptyFeed());
    _relationChanges = RelationChanges.stream.listen((_) {
      if (!mounted || !AccountSession.isCurrent(_sessionGeneration)) return;
      _feedRevision++;
      setState(() { profiles = []; _prefetchedProfiles = []; currentIndex = 0; });
      unawaited(loadFeed());
    });
    _commerceEvents = CommerceEvents.stream.listen((_) {
      if (!mounted || !AccountSession.isCurrent(_sessionGeneration)) return;
      _feedRevision++;
      _prefetchedProfiles = [];
      unawaited(loadFeed());
    });
    loadFeed();
    _loadMyFilterValues();
    loadUnreadStatus();
    loadMyPhoto();
  }

  @override
  void dispose() {
    _commerceEvents?.cancel();
    _relationChanges?.cancel();
    _emptyFeedTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _dragNotifier.dispose();
    _isDraggingNotifier.dispose();
    _anim.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
      unawaited(loadFeed());
      loadUnreadStatus();
    }
  }

  Future<void> loadFeed({bool background = false}) async {
    if (!mounted || !AccountSession.isCurrent(_sessionGeneration)) return;
    if (_feedRequestRunning) {
      if (!background) _feedReloadPending = true;
      return;
    }
    final revision = _feedRevision;
    _feedRequestRunning = true;
    if (!background) {
      setState(() { isLoading = true; error = null; });
    }

    try {
      final data = await _authService.getSwipeFeed(
        minAge: _minAge,
        maxAge: _maxAge,
      );

      if (!mounted || !AccountSession.isCurrent(_sessionGeneration)) return;
      if (revision != _feedRevision) { _feedReloadPending = true; return; }
      final loadedProfiles = List<SwipeProfile>.from(data['profiles']);
      final loadedRadius = (data['radiusKm'] as num).toDouble();

      setState(() {
        _isPaused = data['isPaused'] == true;
        profiles = loadedProfiles;
        _radiusKm = loadedRadius;
        currentIndex = 0;
        isLoading = false;
        error = loadedProfiles.isEmpty ? "Inga profiler just nu" : null;
      });

      _precacheNextProfile();
      if (loadedProfiles.isNotEmpty) _prefetchMoreProfiles();
    } catch (e) {
      if (!mounted || !AccountSession.isCurrent(_sessionGeneration) || background) return;
      debugPrint('LOAD FEED ERROR: $e');

      setState(() {
        error = "Kunde inte ladda feed";
        isLoading = false;
      });
    } finally {
      _feedRequestRunning = false;
      if (_feedReloadPending) {
        _feedReloadPending = false;
        unawaited(loadFeed());
      }
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
      if (!mounted) return;
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
      setState(() {
        currentIndex++;
      });

      _precacheNextProfile();

      final remaining = profiles.length - currentIndex - 1;

      if (remaining <= 2) {
        if (_prefetchedProfiles.isNotEmpty) {
          setState(() {
            profiles.addAll(_prefetchedProfiles);
            _prefetchedProfiles = [];
          });

          _precacheNextProfile();
          _prefetchMoreProfiles();
        } else {
          _prefetchMoreProfiles();
        }
      }
    } else {
      if (_prefetchedProfiles.isNotEmpty) {
        setState(() {
          profiles.addAll(_prefetchedProfiles);
          _prefetchedProfiles = [];
          currentIndex++;
        });

        _precacheNextProfile();
        _prefetchMoreProfiles();
      } else {
        loadFeed();
      }
    }
  }

    Future<void> _prefetchMoreProfiles() async {
    if (_isPrefetching) return;
    if (_prefetchedProfiles.isNotEmpty) return;

    final revision = _feedRevision;
    _isPrefetching = true;

    try {
      final data = await _authService.getSwipeFeed(
        minAge: _minAge,
        maxAge: _maxAge,
      );

      final fetchedProfiles = List<SwipeProfile>.from(data['profiles']);
      final loadedRadius = (data['radiusKm'] as num).toDouble();

      if (!mounted || !AccountSession.isCurrent(_sessionGeneration)) return;

      if (revision != _feedRevision) return;
      final existingIds = profiles.map((p) => p.userId).toSet();
      final filteredProfiles = fetchedProfiles
          .where((p) => !existingIds.contains(p.userId))
          .toList();

      _prefetchedProfiles = filteredProfiles;

      setState(() {
        _radiusKm = loadedRadius;
      });

      for (final profile in _prefetchedProfiles.take(2)) {
        if (profile.photoUrls.isNotEmpty) {
          precacheImage(
            ProfileImages.card(profile.photoUrls.first),
            context,
          );
        }
      }
    } catch (_) {
      // tyst i bakgrunden
    } finally {
      _isPrefetching = false;
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

  Future<void> _logout() async {
    // Clearing auth removes this tab before its storage operation completes.
    // The app navigator outlives the tab and owns the signed-out route.
    final navigator = Navigator.of(context);
    await _authService.logout();
    if (!navigator.mounted) return;
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomePage()),
      (route) => false,
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

    final curve = CurvedAnimation(parent: _anim, curve: Curves.fastOutSlowIn);

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
        final matched = await _authService.like(p.userId, superLike: dir == SwipeDir.up);
        if (dir == SwipeDir.up) CommerceEvents.walletChanged();
        if (matched) {
          await showMatchPopup(other: p);
        } else if (dir == SwipeDir.up) {
          showToast("Super Like skickad ⭐");
        }
      } catch (e) {
        if ((e is CommerceException && (e.status == 429 || e.status == 402)) || e.toString().contains("429")) {
          showToast(dir == SwipeDir.up ? "Du har inga Superlikes kvar ⭐" : "Du har nått like-gränsen ❤️");

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
    final offX = size.width * 1.35;
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
    
    if (profiles.length - currentIndex < 3){
      loadFeed();
    }

    nextProfile();
  }

  Future<void> _rewind() async {
    if (_rewindInFlight || _isAnimating || isLoading) return;
    _rewindInFlight = true;
    try {
      await CommerceClient().rewind();
      if (!mounted || !AccountSession.isCurrent(_sessionGeneration)) return;
      _feedRevision++;
      _prefetchedProfiles = [];
      await loadFeed();
      showToast('Senaste swipen ångrades');
    } on CommerceException catch (error) {
      if (!mounted) return;
      if (error.status == 402) { await Navigator.push(context, MaterialPageRoute(builder: (_) => const PremiumPage())); }
      else { showToast(error.message); }
    } catch (_) { if (mounted) showToast('Kunde inte ångra. Försök igen.'); }
    finally { _rewindInFlight = false; }
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

      for (final url in profile.photoUrls.take(1)) {
        precacheImage(
          ProfileImages.card(url),
          context,
        );
      }
    }
  }

  Future<void> _loadMyFilterValues() async {
    try {
      final me = await _authService.getMyProfile();
      final user = (me['userId'] ?? '').toString();
      final preferences = user.isEmpty ? null : await SharedPreferences.getInstance();
      final previousMinAge = _minAge;
      final previousMaxAge = _maxAge;
      final savedAges = preferences?.getString('discovery_age_$user')?.split(',').map(int.tryParse).toList();
      if (!mounted || !AccountSession.isCurrent(_sessionGeneration)) return;
      setState(() {
        _preferenceUserId = user.isEmpty ? null : user;
        if (savedAges != null && savedAges.length == 2 && savedAges[0] != null && savedAges[1] != null && savedAges[0]! >= 18 && savedAges[1]! <= 99 && savedAges[0]! <= savedAges[1]!) {
          _minAge = savedAges[0]!; _maxAge = savedAges[1]!;
        }
        _interestedIn = (me["interestedIn"] ?? "Alla").toString();
        _radiusKm = (me["matchRadiusKm"] as num?)?.toDouble() ?? _radiusKm;
        _selectedIntention = (me["intention"] ?? "Relationship").toString();
        _selectedReligion = (me["religion"] ?? "Private").toString();
      });
      if (previousMinAge != _minAge || previousMaxAge != _maxAge) {
        _feedRevision++; _prefetchedProfiles = []; unawaited(loadFeed());
      }
    } catch (_) {}
  }

  Future<void> _openRadiusSheet() async {
    await _loadMyFilterValues();
    if (!mounted || !AccountSession.isCurrent(_sessionGeneration)) return;
    await showModalBottomSheet<void>(context: context, isScrollControlled: true,
      showDragHandle: true, backgroundColor: Colors.white,
      builder: (_) => DiscoverySettingsSheet(
        initial: DiscoveryPreferences(interestedIn: _interestedIn, radiusKm: _radiusKm.round(), minAge: _minAge, maxAge: _maxAge),
        onSave: (values) async {
          final user = _preferenceUserId;
          AccountSession.check(_sessionGeneration);
          final preferences = user == null ? null : await SharedPreferences.getInstance();
          await _authService.updateFilterProfile(matchRadiusKm: values.radiusKm, interestedIn: values.interestedIn,
            intention: _selectedIntention, religion: _selectedReligion);
          AccountSession.check(_sessionGeneration);
          // Age ranges are device preferences, scoped to the authenticated account.
          // Interest and radius are authoritative profile fields on the server.
          await preferences?.setString('discovery_age_$user', '${values.minAge},${values.maxAge}');
          if (!mounted || !AccountSession.isCurrent(_sessionGeneration)) return;
          setState(() {
            _feedRevision++; _prefetchedProfiles = []; profiles = []; currentIndex = 0;
            _interestedIn = values.interestedIn; _radiusKm = values.radiusKm.toDouble();
            _minAge = values.minAge; _maxAge = values.maxAge;
          });
          unawaited(loadFeed());
        },
      ));
  }

  Future<void> _openMatchesPage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MatchesPage()),
    );

    if (!mounted) return;
    await loadUnreadStatus();
  }


  Future<void> _openAccountManagement() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountManagementPage()));
    if (mounted && AccountSession.isCurrent(_sessionGeneration)) await loadFeed();
  }

  Widget _buildEmptyFeedState() => Center(child: SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(24, 110, 24, 100),
    child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(_isPaused ? Icons.pause_circle_outline : Icons.travel_explore_rounded, color: Colors.white, size: 54),
      const SizedBox(height: 20), Text(_isPaused ? 'Ditt konto är pausat' : 'Inga profiler just nu', textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
      const SizedBox(height: 16), Text(_isPaused
        ? 'Återaktivera kontot när du vill upptäcka nya personer igen. Dina matchningar och chattar finns kvar.'
        : 'Testa att öka avståndet eller ändra åldersspannet i filtret.',
        textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 17, height: 1.5)),
      const SizedBox(height: 24), SizedBox(width: double.infinity, child: FilledButton(
        style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE6296B), foregroundColor: Colors.white, padding: const EdgeInsets.all(16)),
        onPressed: _isPaused ? _openAccountManagement : _openRadiusSheet,
        child: Text(_isPaused ? 'Hantera paus' : 'Öppna filter'))),
    ])),
  ));

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
      onRewind: _rewind,
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
      nextCard: _getNextCard(nextProfile),
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
        final cardHeight = constraints.maxHeight - 120;
        return Center(
          child: Transform.translate(
            offset: const Offset(0, _nextCardOffsetY),
            child: Transform.scale(
              scale: _nextCardScale,
              alignment: Alignment.center,
              child: Opacity(
                opacity: 0.88,
                child: IgnorePointer(
                  child: RepaintBoundary(
                    child: SizedBox(
                      width: cardWidth,
                      height: cardHeight,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(_cardCornerRadius),
                        child: ColorFiltered(
                          colorFilter: ColorFilter.mode(
                            Colors.black.withOpacity(0.03),
                            BlendMode.darken,
                          ),
                          child: SwipeProfileCard(
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

  Widget? _getNextCard(SwipeProfile? nextProfile) {
  if (nextProfile == null) {
    _cachedNextCard = null;
    _cachedNextCardUserId = null;
    return null; 
  }

  if (_cachedNextCardUserId == nextProfile.userId && _cachedNextCard != null) {
    return _cachedNextCard;
  }

  _cachedNextCardUserId = nextProfile.userId;
  _cachedNextCard = _buildNextCard(nextProfile);
  return _cachedNextCard;
}

    Widget _buildActiveCard(SwipeProfile p) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth;
        final cardHeight = constraints.maxHeight - 120;
        return ValueListenableBuilder<Offset>(
          valueListenable: _dragNotifier,
          builder: (context, dragValue, _) {
            return ValueListenableBuilder<bool>(
              valueListenable: _isDraggingNotifier,
              builder: (context, draggingValue, __) {
                final activeOffset = _animOffset?.value ?? dragValue;
                final activeRot =
                    _animRotate?.value ?? (dragValue.dx / 520.0).clamp(-0.11, 0.11);
                final activeFade = _animFade?.value ?? 1.0;

                return Center(
                  child: Transform.translate(
                    offset: const Offset(0, _activeCardLift),
                    child: GestureDetector(
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
                                child: SizedBox(
                                  width: cardWidth,
                                  height: cardHeight,
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      SwipeProfileCard(
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

