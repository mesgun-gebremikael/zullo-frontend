import '../l10n/localization.dart';
import 'profile_story.dart' show localizedProfileChoice;
import '../profile_page.dart';
import '../services/profile_images.dart';
import 'package:flutter/material.dart';

import '../models/swipe_profile.dart';

class SwipeProfileCard extends StatefulWidget {
  final SwipeProfile profile;
  final double width;
  final double height;
  final double photoBarsTop;
  final double distanceFallbackKm;
  final ImageProvider Function(String)? imageProvider;

  const SwipeProfileCard({
    super.key,
    required this.profile,
    required this.width,
    required this.height,
    this.photoBarsTop = 16,
    this.distanceFallbackKm = 50,
    this.imageProvider,
  });

  @override
  State<SwipeProfileCard> createState() => _SwipeProfileCardState();
}

enum _CardContentGroup {
  intro,
  background,
  aboutLife,
  workStudy,
  lookingFor,
}

class _SwipeProfileCardState extends State<SwipeProfileCard> {
  int imageIndex = 0;
  int _imageRevision = 0;

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
      _precacheNextPhoto();
    });
  }

  @override
  void didUpdateWidget(covariant SwipeProfileCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldPhotos = oldWidget.profile.photoUrls;
    final newPhotos = widget.profile.photoUrls;

    final userChanged = oldWidget.profile.userId != widget.profile.userId;
    final photosChanged = oldPhotos.join('|') != newPhotos.join('|');

    if (userChanged || photosChanged) {
      imageIndex = 0;
      // A different user must never briefly inherit the previous user's photo.
      _visibleImageUrl = '';

      final newUrl = _currentPhotoUrl();
      _resolveVisibleImage(newUrl);

      WidgetsBinding.instance.addPostFrameCallback((_) {
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

  ImageProvider _provider(String url) =>
      widget.imageProvider?.call(url) ?? ProfileImages.card(url);

  void _removeImageListener() {
    if (_imageStream != null && _imageListener != null) {
      _imageStream!.removeListener(_imageListener!);
    }

    _imageStream = null;
    _imageListener = null;
  }

  void _resolveVisibleImage(String url) {
    final revision = ++_imageRevision;
    if (url.isEmpty) {
      setState(() {
        _visibleImageUrl = '';
        _isImageReady = true;
      });
      return;
    }

    final provider = _provider(url);
    final stream = provider.resolve(const ImageConfiguration());

    _removeImageListener();

    _imageStream = stream;
    _imageListener = ImageStreamListener(
      (ImageInfo _, bool __) {
        if (!mounted || revision != _imageRevision) return;

        setState(() {
          _visibleImageUrl = url;
          _isImageReady = true;
        });

        _removeImageListener();
      },
      onError: (dynamic _, StackTrace? __) {
        if (!mounted || revision != _imageRevision) return;

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

  void _precacheNextPhoto() {
    if (!mounted) return;
    final profile = widget.profile;

    if (profile.photoUrls.isEmpty) return;

    final nextIndex = imageIndex + 1;
    if (nextIndex >= profile.photoUrls.length) return;

    precacheImage(
      _provider(profile.photoUrls[nextIndex]),
      context,
    );
  }

  bool _hasBackgroundData(SwipeProfile profile) {
    return profile.originPlace.trim().isNotEmpty ||
        localizedProfileChoice(context, 'religion', profile.religion)
            .isNotEmpty;
  }

  bool _hasAboutLifeData(SwipeProfile profile) {
    return profile.zodiacSign.trim().isNotEmpty ||
        profile.wantChildren.trim().isNotEmpty ||
        profile.workout.trim().isNotEmpty ||
        profile.smoking.trim().isNotEmpty ||
        profile.alcohol.trim().isNotEmpty ||
        profile.relationshipHistory.trim().isNotEmpty ||
        profile.pets.trim().isNotEmpty ||
        profile.childrenCount.trim().isNotEmpty;
  }

  bool _hasWorkStudyData(SwipeProfile profile) {
    return (profile.heightCm ?? 0) > 0 ||
        profile.workStatus.trim().isNotEmpty ||
        profile.studyPlace.trim().isNotEmpty ||
        profile.studySubject.trim().isNotEmpty ||
        profile.workPlace.trim().isNotEmpty ||
        profile.jobTitle.trim().isNotEmpty;
  }

  bool _hasLookingForData(SwipeProfile profile) {
    return profile.intention.trim().isNotEmpty;
  }

  List<_CardContentGroup> _contentGroupsForProfile(SwipeProfile profile) {
    final groups = <_CardContentGroup>[
      _CardContentGroup.intro,
    ];

    if (_hasBackgroundData(profile)) {
      groups.add(_CardContentGroup.background);
    }

    if (_hasAboutLifeData(profile)) {
      groups.add(_CardContentGroup.aboutLife);
    }

    if (_hasWorkStudyData(profile)) {
      groups.add(_CardContentGroup.workStudy);
    }

    if (_hasLookingForData(profile)) {
      groups.add(_CardContentGroup.lookingFor);
    }

    final targetCount =
        profile.photoUrls.isNotEmpty ? profile.photoUrls.length : 1;

    while (groups.length < targetCount) {
      groups.add(groups.last);
    }

    return groups;
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
            color: Colors.black.withValues(alpha: 0.22),
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

                final forward = (tapX > width / 2) !=
                    (Directionality.of(context) == TextDirection.rtl);
                if (forward) {
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
                          Image(
                            key: ValueKey(widget.profile.userId),
                            image: _provider(_visibleImageUrl),
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
                        child: Icon(
                          Icons.person,
                          size: 120,
                          color: Colors.white,
                        ),
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
                      margin: EdgeInsetsDirectional.only(
                        end: index == profile.photoUrls.length - 1 ? 0 : 4,
                      ),
                      decoration: BoxDecoration(
                        color: isActive
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.28),
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
                      Colors.black.withValues(alpha: 0.28),
                      Colors.black.withValues(alpha: 0.10),
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
                      Colors.black.withValues(alpha: 0.0),
                      Colors.black.withValues(alpha: 0.18),
                      Colors.black.withValues(alpha: 0.82),
                    ],
                  ),
                ),
              ),
            ),
            _buildBottomContent(profile),
            if (profile.superLikedYou)
              PositionedDirectional(
                top: widget.photoBarsTop + 14,
                start: 16,
                child: DecoratedBox(
                    decoration: BoxDecoration(
                        color: const Color(0xFF1879D8),
                        borderRadius: BorderRadius.circular(20)),
                    child: Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.star_rounded,
                              color: Colors.white, size: 19),
                          SizedBox(width: 6),
                          Text(context.l10n.haveSuperlikedYou,
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700)),
                        ]))),
              ),
          ],
        ),
      ),
    );
  }

  Widget _detailsButton(SwipeProfile profile) => IconButton(
        tooltip: context.l10n.readTheFullProfile,
        onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ProfilePage(profile: profile))),
        style: IconButton.styleFrom(
            backgroundColor: Colors.black.withValues(alpha: .42),
            foregroundColor: Colors.white,
            minimumSize: const Size(48, 48)),
        icon: const Icon(Icons.arrow_upward_rounded, size: 21),
      );

  Widget _buildBottomContent(SwipeProfile profile) {
    final groups = _contentGroupsForProfile(profile);

    final safeIndex =
        imageIndex < groups.length ? imageIndex : groups.length - 1;

    final group = groups[safeIndex];

    switch (group) {
      case _CardContentGroup.intro:
        return _buildImage0(profile);
      case _CardContentGroup.background:
        return _buildImage1(profile);
      case _CardContentGroup.aboutLife:
        return _buildImage2(profile);
      case _CardContentGroup.workStudy:
        return _buildImage3(profile);
      case _CardContentGroup.lookingFor:
        return _buildImage4(profile);
    }
  }

  Widget _buildImage0(SwipeProfile profile) {
    final livingText = profile.livePlace.trim().isNotEmpty
        ? "${context.l10n.currentCity} · ${profile.livePlace.trim()}"
        : "";
    final distanceText =
        context.l10n.value0Km(profile.distanceKm.round().toString());

    return Stack(
      children: [
        Positioned(
          left: 20,
          right: 20,
          bottom: 96,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildBottomName(profile),
              const SizedBox(height: 8),
              _infoRow(
                icon: Icons.location_on_outlined,
                text: distanceText,
              ),
              if (livingText.isNotEmpty) ...[
                const SizedBox(height: 8),
                _infoRow(
                  icon: Icons.home_outlined,
                  text: livingText,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImage1(SwipeProfile profile) {
    final hasOrigin = profile.originPlace.trim().isNotEmpty;
    final hasReligion =
        localizedProfileChoice(context, 'religion', profile.religion)
            .isNotEmpty;

    return Stack(
      children: [
        Positioned(
          left: 20,
          right: 20,
          bottom: 96,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildBottomName(profile),
              const SizedBox(height: 8),
              if (hasOrigin)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _infoRow(
                    icon: Icons.public_rounded,
                    text: profile.originPlace.trim(),
                  ),
                ),
              if (hasReligion)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _religionRow(profile.religion.trim()),
                ),
              if (!hasOrigin && !hasReligion)
                _infoRow(
                  icon: Icons.info_outline_rounded,
                  text: context.l10n.addMoreDetails,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImage2(SwipeProfile profile) {
    final aboutLifeItems = <MapEntry<IconData, String>>[
      if (_formatRelationshipHistory(profile.relationshipHistory)
          .trim()
          .isNotEmpty)
        MapEntry(
          _relationshipHistoryIcon(profile.relationshipHistory),
          _formatRelationshipHistory(profile.relationshipHistory).trim(),
        ),
      if (profile.zodiacSign.trim().isNotEmpty)
        MapEntry(
          _zodiacIcon(profile.zodiacSign),
          localizedProfileChoice(context, 'zodiacSign', profile.zodiacSign),
        ),
      if (_formatWantChildren(profile.wantChildren).trim().isNotEmpty)
        MapEntry(
          _wantChildrenIcon(profile.wantChildren),
          _formatWantChildren(profile.wantChildren).trim(),
        ),
      if (_formatChildrenCount(profile.childrenCount).trim().isNotEmpty)
        MapEntry(
          _childrenCountIcon(profile.childrenCount),
          _formatChildrenCount(profile.childrenCount).trim(),
        ),
      if (_formatWorkout(profile.workout).trim().isNotEmpty)
        MapEntry(
          _workoutIcon(profile.workout),
          _formatWorkout(profile.workout).trim(),
        ),
      if (_formatSmoking(profile.smoking).trim().isNotEmpty)
        MapEntry(
          _smokingIcon(profile.smoking),
          _formatSmoking(profile.smoking).trim(),
        ),
      if (_formatAlcohol(profile.alcohol).trim().isNotEmpty)
        MapEntry(
          _alcoholIcon(profile.alcohol),
          _formatAlcohol(profile.alcohol).trim(),
        ),
      if (_formatPets(profile.pets).trim().isNotEmpty)
        MapEntry(
          _petsIcon(profile.pets),
          _formatPets(profile.pets).trim(),
        ),
    ];

    final visibleItems = aboutLifeItems.take(8).toList();

    return Stack(
      children: [
        Positioned(
          left: 20,
          right: 20,
          bottom: 88,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildBottomName(profile),
              const SizedBox(height: 8),
              _sectionTitle(
                icon: Icons.tune_rounded,
                title: "Min livsstil",
              ),
              const SizedBox(height: 8),
              _iconChipWrap(
                visibleItems.isNotEmpty
                    ? visibleItems
                    : [
                        const MapEntry(
                          Icons.info_outline_rounded,
                          "Lägg till mer info",
                        ),
                      ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImage3(SwipeProfile profile) {
    final details = <MapEntry<IconData, String>>[
      if (_formatHeight(profile.heightCm).trim().isNotEmpty)
        MapEntry(
          Icons.height_rounded,
          _formatHeight(profile.heightCm).trim(),
        ),
      if (profile.studyPlace.trim().isNotEmpty ||
          profile.studySubject.trim().isNotEmpty)
        MapEntry(
          Icons.school_rounded,
          profile.studyPlace.trim().isNotEmpty &&
                  profile.studySubject.trim().isNotEmpty
              ? "${profile.studyPlace.trim()} • ${profile.studySubject.trim()}"
              : profile.studyPlace.trim().isNotEmpty
                  ? profile.studyPlace.trim()
                  : profile.studySubject.trim(),
        ),
      if (profile.jobTitle.trim().isNotEmpty ||
          profile.workPlace.trim().isNotEmpty)
        MapEntry(
          Icons.work_outline_rounded,
          profile.jobTitle.trim().isNotEmpty &&
                  profile.workPlace.trim().isNotEmpty
              ? "${profile.jobTitle.trim()} • ${profile.workPlace.trim()}"
              : profile.jobTitle.trim().isNotEmpty
                  ? profile.jobTitle.trim()
                  : profile.workPlace.trim(),
        ),
    ];

    return Stack(
      children: [
        Positioned(
          left: 20,
          right: 20,
          bottom: 96,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildBottomName(profile),
              const SizedBox(height: 18),
              if (details.isNotEmpty)
                ...details.map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _infoRow(
                      icon: item.key,
                      text: item.value,
                    ),
                  );
                }),
              if (details.isEmpty)
                _infoRow(
                  icon: Icons.info_outline_rounded,
                  text: context.l10n.addMoreDetails,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImage4(SwipeProfile profile) {
    final lookingItems = <MapEntry<IconData, String>>[
      if (_formatIntention(profile.intention).trim().isNotEmpty)
        MapEntry(
          _intentionIcon(profile.intention),
          _formatIntention(profile.intention).trim(),
        ),
    ];

    return Stack(
      children: [
        Positioned(
          left: 20,
          right: 20,
          bottom: 96,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildBottomName(profile),
              const SizedBox(height: 8),

              // 🔍 Titel som Tinder
              _sectionTitle(
                icon: Icons.search_rounded,
                title: "Söker",
              ),

              const SizedBox(height: 8),

              _iconChipWrap(
                lookingItems.isNotEmpty
                    ? lookingItems
                    : [
                        const MapEntry(
                          Icons.info_outline_rounded,
                          "Inte angivet",
                        ),
                      ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle({
    required IconData icon,
    required String title,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: 19,
          color: Colors.white,
        ),
        const SizedBox(width: 7),
        Text(
          context.tr(title),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16.5,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
            height: 1.0,
          ),
        ),
      ],
    );
  }

  Widget _infoRow({required IconData icon, required String text}) {
    return Row(
      children: [
        icon == Icons.straighten
            ? Transform.rotate(
                angle: -1.18, // 90 grader

                child: Icon(
                  icon,
                  color: Colors.white.withValues(alpha: 0.9),
                  size: 17,
                ),
              )
            : Icon(
                icon,
                color: Colors.white.withValues(alpha: 0.9),
                size: 17,
              ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.90),
              fontSize: 14.5,
              fontWeight: FontWeight.w500,
              height: 1.1,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomName(SwipeProfile profile) => Row(
        children: [
          Expanded(
              child: DefaultTextStyle(
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              height: 1.0,
              letterSpacing: -0.4,
            ),
            child: Row(children: [
              Flexible(
                  child: Text(profile.displayName,
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 8),
              Text(profile.age.toString(), maxLines: 1),
            ]),
          )),
          const SizedBox(width: 12),
          _detailsButton(profile),
        ],
      );

  Widget _religionRow(String religion) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.28),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.18),
            ),
          ),
          child: Text(
            _religionSymbol(religion),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.0,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            localizedProfileChoice(context, 'religion', religion),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.90),
              fontSize: 15,
              fontWeight: FontWeight.w500,
              height: 1.15,
            ),
          ),
        ),
      ],
    );
  }

  Widget _iconChip({
    required IconData icon,
    required String text,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        maxWidth: 170,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: Colors.white,
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                softWrap: true,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconChipWrap(List<MapEntry<IconData, String>> items) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: items.take(8).map((item) {
        return _iconChip(
          icon: item.key,
          text: item.value,
        );
      }).toList(),
    );
  }

  String _formatWorkout(String value) =>
      localizedProfileChoice(context, 'workout', value);

  String _formatPets(String value) =>
      localizedProfileChoice(context, 'pets', value);

  String _formatIntention(String value) =>
      localizedProfileChoice(context, 'intention', value);

  IconData _intentionIcon(String value) {
    switch (value.trim()) {
      case 'Friendship':
        return Icons.people_outline_rounded;
      case 'Date':
        return Icons.local_bar_rounded;
      case 'Relationship':
        return Icons.favorite_rounded;
      case 'Marriage':
        return Icons.ring_volume_rounded;
      case 'Serious':
        return Icons.favorite_border_rounded;
      case 'NotSure':
        return Icons.psychology_alt_rounded;
      default:
        return Icons.search_rounded;
    }
  }

  String _formatHeight(int? value) {
    if (value == null || value <= 0) return '';
    return context.l10n.heightCentimeters(value.toString());
  }

  String _formatRelationshipHistory(String value) =>
      localizedProfileChoice(context, 'relationshipHistory', value);

  String _formatWantChildren(String value) =>
      localizedProfileChoice(context, 'wantChildren', value);

  String _formatChildrenCount(String value) =>
      localizedProfileChoice(context, 'childrenCount', value);

  String _religionSymbol(String value) {
    switch (value.trim()) {
      case 'Ortodox':
      case 'Orthodox':
        return '☦';
      case 'Kristen':
      case 'Christian':
      case 'Katolik':
      case 'Catholic':
        return '✝';
      case 'Muslim':
      case 'Islam':
        return '☪';
      case 'Judisk':
      case 'Jewish':
        return '✡';
      case 'Hindu':
      case 'Hinduism':
        return '🕉';
      case 'Buddhist':
      case 'Buddhism':
        return '☸';
      case 'Sikh':
        return '☬';
      case 'Agnostiker':
      case 'Ateist':
      case 'Atheist':
      case 'Private':
      case 'Privat':
      case 'Annat':
      default:
        return '✦';
    }
  }

  String _formatSmoking(String value) =>
      localizedProfileChoice(context, 'smoking', value);

  String _formatAlcohol(String value) =>
      localizedProfileChoice(context, 'alcohol', value);

  IconData _relationshipHistoryIcon(String value) {
    switch (value) {
      case 'relationship':
      case 'Relationship':
        return Icons.favorite_rounded;
      case 'casual':
      case 'Casual':
        return Icons.people_alt_rounded;
      case 'never':
      case 'Never':
        return Icons.heart_broken_rounded;
      default:
        return Icons.favorite_border_rounded;
    }
  }

  IconData _wantChildrenIcon(String value) {
    switch (value) {
      case 'yes':
        return Icons.stroller_rounded;
      case 'maybe':
        return Icons.child_care_rounded;
      case 'no':
        return Icons.block_rounded;
      default:
        return Icons.stroller_outlined;
    }
  }

  IconData _childrenCountIcon(String value) {
    return Icons.child_friendly_rounded;
  }

  IconData _workoutIcon(String value) {
    switch (value) {
      case 'Never':
        return Icons.fitness_center_outlined;
      case 'Sometimes':
        return Icons.fitness_center_rounded;
      case 'Often':
        return Icons.sports_gymnastics_rounded;
      default:
        return Icons.fitness_center_outlined;
    }
  }

  IconData _smokingIcon(String value) {
    switch (value) {
      case 'No':
        return Icons.smoke_free_rounded;
      case 'Sometimes':
        return Icons.smoking_rooms_outlined;
      case 'Yes':
        return Icons.smoking_rooms_rounded;
      default:
        return Icons.smoking_rooms_outlined;
    }
  }

  IconData _alcoholIcon(String value) {
    switch (value) {
      case 'No':
        return Icons.no_drinks_rounded;
      case 'Sometimes':
        return Icons.wine_bar_outlined;
      case 'Yes':
        return Icons.local_bar_rounded;
      default:
        return Icons.local_bar_outlined;
    }
  }

  IconData _petsIcon(String value) {
    switch (value) {
      case 'Have':
        return Icons.pets_rounded;
      case 'Want':
        return Icons.pets_outlined;
      case 'No':
        return Icons.block_rounded;
      case 'Allergic':
        return Icons.healing_rounded;
      default:
        return Icons.pets_outlined;
    }
  }

  IconData _zodiacIcon(String value) {
    return Icons.auto_awesome_rounded;
  }
}
