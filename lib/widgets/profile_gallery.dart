import 'package:flutter/material.dart';
import '../services/profile_images.dart';

/// Both touch gestures and explicit controls work on phones and emulators.
class ProfileGallery extends StatefulWidget {
  final List<String> photos;
  final ImageProvider Function(String)? imageProvider;
  const ProfileGallery({super.key, required this.photos, this.imageProvider});
  @override
  State<ProfileGallery> createState() => _ProfileGalleryState();
}

class _ProfileGalleryState extends State<ProfileGallery> {
  final _controller = PageController();
  int _index = 0;
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _move(int delta) {
    final page = (_index + delta).clamp(0, widget.photos.length - 1);
    if (page != _index) {
      _controller.animateToPage(page,
          duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
    }
  }

  @override
  void didUpdateWidget(covariant ProfileGallery oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photos != widget.photos && _index >= widget.photos.length) {
      _index = 0;
      if (_controller.hasClients) _controller.jumpToPage(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return SizedBox(
        height: (MediaQuery.sizeOf(context).height * .65).clamp(360.0, 620.0),
        child: Stack(fit: StackFit.expand, children: [
          if (widget.photos.isEmpty)
            const ColoredBox(
                color: Color(0xFFF0F2F6),
                child: Center(child: Icon(Icons.person_outline, size: 80)))
          else
            PageView.builder(
              controller: _controller,
              itemCount: widget.photos.length,
              onPageChanged: (value) => setState(() => _index = value),
              itemBuilder: (context, i) => LayoutBuilder(
                  builder: (context, box) => GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: (event) => _move(
                          (event.localPosition.dx < box.maxWidth / 2) != rtl
                              ? -1
                              : 1),
                      child: Image(
                          key: ValueKey(widget.photos[i]),
                          image: (widget.imageProvider ??
                              ProfileImages.card)(widget.photos[i]),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const ColoredBox(
                              color: Color(0xFFF0F2F6),
                              child: Center(
                                  child:
                                      Icon(Icons.person_outline, size: 72, color: Color(0xFF697180))))))),
            ),
          const IgnorePointer(
              child: DecoratedBox(
                  decoration: BoxDecoration(
                      gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.center,
                          colors: [Colors.black45, Colors.transparent])))),
          if (widget.photos.length > 1) ...[
            Positioned(
                top: 12,
                left: 16,
                right: 16,
                child: IgnorePointer(
                    child: Row(
                        children: List.generate(
                            widget.photos.length,
                            (i) => Expanded(
                                child: Container(
                                    height: 3,
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 2),
                                    decoration: BoxDecoration(
                                        color: i == _index
                                            ? Colors.white
                                            : Colors.white38,
                                        borderRadius:
                                            BorderRadius.circular(10)))))))),
            if (_index > 0)
              Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: _button(
                      rtl
                          ? Icons.chevron_right_rounded
                          : Icons.chevron_left_rounded,
                      'Föregående bild',
                      -1)),
            if (_index + 1 < widget.photos.length)
              Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: _button(
                      rtl
                          ? Icons.chevron_left_rounded
                          : Icons.chevron_right_rounded,
                      'Nästa bild',
                      1)),
          ],
          if (widget.photos.isNotEmpty)
            Positioned(
                bottom: 18,
                right: 18,
                child: IgnorePointer(
                    child: DecoratedBox(
                        decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(20)),
                        child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 7),
                            child: Text(
                                '${_index + 1} / ${widget.photos.length}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700))))))
        ]));
  }

  Widget _button(IconData icon, String label, int delta) => Padding(
      padding: const EdgeInsets.all(8),
      child: IconButton(
          tooltip: label,
          onPressed: () => _move(delta),
          style: IconButton.styleFrom(
              backgroundColor: Colors.black38,
              foregroundColor: Colors.white,
              minimumSize: const Size(48, 48)),
          icon: Icon(icon, size: 28)));
}
