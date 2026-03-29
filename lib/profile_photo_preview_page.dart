import 'package:flutter/material.dart';

class ProfilePhotoPreviewPage extends StatelessWidget {
  final String imageUrl;

  const ProfilePhotoPreviewPage({
    super.key,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return const Text(
                'Kunde inte ladda bilden',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}