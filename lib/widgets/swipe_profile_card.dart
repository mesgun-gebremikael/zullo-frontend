import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/swipe_profile.dart';

class SwipeProfileCard extends StatefulWidget {
  final SwipeProfile profile;
  final double width;
  final double height;
  final double photoBarsTop;
  final double distanceFallbackKm;

  const SwipeProfileCard({
    super.key,
    required this.profile,
    required this.width,
    required this.height,
    this.photoBarsTop = 66,
    this.distanceFallbackKm = 50,
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
  void didUpdateWidget(covariant SwipeProfileCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldPhotos = oldWidget.profile.photoUrls;
    final newPhotos = widget.profile.photoUrls;

    final userChanged = oldWidget.profile.userId != widget.profile.userId;
    final photosChanged = oldPhotos.join('|') != newPhotos.join('|');

    if (userChanged || photosChanged) {
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

    final provider = CachedNetworkImageProvider(url);
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
        CachedNetworkImageProvider(url),
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
      CachedNetworkImageProvider(profile.photoUrls[nextIndex]),
      context,
    );
  }

    bool _hasBackgroundData(SwipeProfile profile) {
    return profile.originPlace.trim().isNotEmpty ||
        profile.religion.trim().isNotEmpty;
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

    final targetCount = profile.photoUrls.isNotEmpty ? profile.photoUrls.length : 1;

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
                      margin: EdgeInsets.only(
                        right: index == profile.photoUrls.length - 1 ? 0 : 4,
                      ),
                      decoration: BoxDecoration(
                        color: isActive
                            ? Colors.white
                            : Colors.white.withOpacity(0.28),
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
    final groups = _contentGroupsForProfile(profile);

    final safeIndex = imageIndex < groups.length
        ? imageIndex
        : groups.length - 1;

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
  final distanceText = profile.distanceKm != null
      ? "${profile.distanceKm!.toStringAsFixed(0)} km bort"
      : "";

  final livePlace = profile.livePlace?.trim() ?? "";

  return Stack(
    children: [
      // 🔥 Namn + ålder
      Positioned(
        left: 20,
        right: 20,
        bottom: 150,
        child: Text(
          "${profile.displayName} ${profile.age}",
          style: const TextStyle(
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      // 📍 KM bort
      if (distanceText.isNotEmpty)
        Positioned(
          left: 20,
          bottom: 120,
          child: Row(
            children: [
              const Icon(Icons.location_on, color: Colors.white70, size: 16),
              const SizedBox(width: 4),
              Text(
                distanceText,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ),

      // 🏠 Bor i
      if (livePlace.isNotEmpty)
        Positioned(
          left: 20,
          bottom: 100,
          child: Row(
            children: [
              const Icon(Icons.home, color: Colors.white70, size: 16),
              const SizedBox(width: 4),
              Text(
                "Bor i $livePlace",
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ),
    ],
  );
}


     Widget _buildImage1(SwipeProfile profile) {
    final backgroundChips = <String>[
      if (profile.originPlace.trim().isNotEmpty)
        "Från ${profile.originPlace.trim()}",
      if (profile.religion.trim().isNotEmpty)
        profile.religion.trim(),
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
                icon: Icons.public_rounded,
                title: "Bakgrund",
              ),
              const SizedBox(height: 10),
              _chipWrap(
                backgroundChips.isNotEmpty
                    ? backgroundChips
                    : ["Lägg till mer info"],
              ),
            ],
          ),
        ),
      ],
    );
  }


     Widget _buildImage2(SwipeProfile profile) {
    final aboutLifeItems = <MapEntry<IconData, String>>[
      if (_formatRelationshipHistory(profile.relationshipHistory).trim().isNotEmpty)
        MapEntry(
          _relationshipHistoryIcon(profile.relationshipHistory),
          _formatRelationshipHistory(profile.relationshipHistory).trim(),
        ),
      if (profile.zodiacSign.trim().isNotEmpty)
        MapEntry(
          _zodiacIcon(profile.zodiacSign),
          profile.zodiacSign.trim(),
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
          right: 84,
          bottom: 246,
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
        Positioned(
          right: 20,
          bottom: 236,
          child: Container(
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
        ),
        Positioned(
          left: 20,
          right: 20,
          bottom: 84,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle(
                icon: Icons.tune_rounded,
                title: "Om mig & Livsstil",
              ),
              const SizedBox(height: 12),
              _iconChipWrap(
                visibleItems.isNotEmpty
                    ? visibleItems
                    : [
                        const MapEntry(Icons.info_outline_rounded, "Lägg till mer info"),
                      ],
              ),
            ],
          ),
        ),
      ],
    );
  }





     Widget _buildImage3(SwipeProfile profile) {
    final workStudyChips = <String>[
      if (_formatHeight(profile.heightCm).trim().isNotEmpty)
        _formatHeight(profile.heightCm).trim(),
      if (_formatWorkStatus(profile.workStatus).trim().isNotEmpty)
        _formatWorkStatus(profile.workStatus).trim(),
      if (profile.studyPlace.trim().isNotEmpty)
        "Pluggar i ${profile.studyPlace.trim()}",
      if (profile.studySubject.trim().isNotEmpty)
        "Studerar ${profile.studySubject.trim()}",
      if (profile.workPlace.trim().isNotEmpty)
        "Jobbar på ${profile.workPlace.trim()}",
      if (profile.jobTitle.trim().isNotEmpty)
        profile.jobTitle.trim(),
    ];

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
                icon: Icons.school_outlined,
                title: "Längd, jobb & skola",
              ),
              const SizedBox(height: 10),
              _chipWrap(
                workStudyChips.isNotEmpty
                    ? workStudyChips
                    : ["Lägg till mer info"],
              ),
            ],
          ),
        ),
      ],
    );
  }


     Widget _buildImage4(SwipeProfile profile) {
    final lookingForText = _formatIntention(profile.intention).trim();

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
                icon: Icons.favorite_border_rounded,
                title: "Vad man söker",
              ),
              const SizedBox(height: 10),
              _chipWrap(
                lookingForText.isNotEmpty
                    ? [lookingForText]
                    : ["Lägg till mer info"],
              ),
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

   Widget _iconChip({
    required IconData icon,
    required String text,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        maxWidth: 190,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.72),
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
                  fontSize: 14.5,
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
      spacing: 10,
      runSpacing: 10,
      children: items.map((item) {
        return _iconChip(
          icon: item.key,
          text: item.value,
        );
      }).toList(),
    );
  }



   String _formatWorkout(String value) {
  switch (value) {
    case 'Never':
      return 'Tränar aldrig';
    case 'Sometimes':
      return 'Tränar ibland';
    case 'Often':
      return 'Tränar ofta';
    default:
      return value;
  }
}

String _formatPets(String value) {
  switch (value) {
    case 'Have':
      return 'Har husdjur';
    case 'Want':
      return 'Vill ha husdjur';
    case 'No':
      return 'Vill inte ha husdjur';
    case 'Allergic':
      return 'Allergisk mot husdjur';
    default:
      return value;
  }
}
  

  
String _formatIntention(String value) {
  switch (value) {
    case 'Relationship':
      return 'Relation';
    case 'Marriage':
      return 'Gifta mig';
    case 'Date':
      return 'Dejta';
    case 'Serious':
      return 'Något seriöst';
    case 'NotSure':
      return 'Jag vet inte än';
    default:
      return '';
  }
}  


String _formatHeight(int? value) {
  if (value == null || value <= 0) return '';
  return '$value cm';
}

String _formatRelationshipHistory(String value) {
  switch (value) {
    case 'relationship':
    case 'Relationship':
      return 'Varit i ett förhållande';
    case 'casual':
    case 'Casual':
      return 'Inget seriöst';
    case 'never':
    case 'Never':
      return 'Aldrig haft ett förhållande';
    default:
      return ''; // 🔥 viktigt
  }
}


String _formatWantChildren(String value) {
  switch (value) {
    case 'yes':
    case 'Yes':
      return 'Jag vill ha barn';
    case 'maybe':
    case 'Maybe':
      return 'Inte säker än';
    case 'no':
    case 'No':
      return 'Jag vill inte ha barn';
    default:
      return value;
  }
}

String _formatChildrenCount(String value) {
  switch (value) {
    case '0':
      return 'Jag har inga barn';
    case '1':
      return '1 barn';
    case '2':
      return '2 barn';
    case '3':
      return '3 barn';
    case '4+':
      return '4 eller fler barn';
    default:
      return value;
  }
}

String _formatWorkStatus(String value) {
  switch (value) {
    case 'study':
    case 'Study':
      return 'Pluggar just nu';
    case 'work':
    case 'Work':
      return 'Jobbar just nu';
    default:
      return ''; // om ingen bild finns retunera tom
  }
}


String _formatSmoking(String value) {
  switch (value) {
    case 'No':
      return 'Jag använder inte nikotin';
    case 'Sometimes':
      return 'Jag använder nikotin ibland';
    case 'Yes':
      return 'Jag använder nikotin';
    default:
      return value;
  }
}

String _formatAlcohol(String value) {
  switch (value) {
    case 'Never':
      return 'Jag dricker inte alkohol';
    case 'Sometimes':
      return 'Jag dricker ibland';
    case 'Often':
      return 'Jag dricker';
    default:
      return value;
  }
}

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