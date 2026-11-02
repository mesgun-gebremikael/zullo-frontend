import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zullo_app/models/swipe_profile.dart';
import 'package:zullo_app/widgets/swipe_profile_card.dart';

class PendingProfileImage extends ImageProvider<PendingProfileImage> {
  final result = Completer<ImageInfo>();
  @override
  Future<PendingProfileImage> obtainKey(
          ImageConfiguration configuration) async =>
      this;
  @override
  ImageStreamCompleter loadImage(
          PendingProfileImage key, ImageDecoderCallback decode) =>
      OneFrameImageStreamCompleter(result.future);
}

void main() {
  testWidgets('late previous-user image cannot appear on the next profile',
      (tester) async {
    final a = PendingProfileImage(), b = PendingProfileImage();
    SwipeProfile profile(String id) => SwipeProfile.fromJson({
          'userId': id,
          'displayName': id,
          'age': 25,
          'photoUrls': [id]
        });
    Widget card(String id) => MaterialApp(
        home: Scaffold(
            body: SwipeProfileCard(
                profile: profile(id),
                width: 350,
                height: 550,
                imageProvider: (url) => url == 'A' ? a : b)));
    await tester.pumpWidget(card('A'));
    await tester.pumpWidget(card('B'));
    final image =
        (await tester.runAsync(() => createTestImage(width: 4, height: 4)))!;
    a.result.complete(ImageInfo(image: image));
    await tester.pump();
    expect(find.byType(Image), findsNothing);
    b.result.complete(ImageInfo(
        image: (await tester
            .runAsync(() => createTestImage(width: 4, height: 4)))!));
    await tester.pumpAndSettle();
    expect(tester.widget<Image>(find.byType(Image)).image, b);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    PaintingBinding.instance.imageCache.clear();
  });
}
