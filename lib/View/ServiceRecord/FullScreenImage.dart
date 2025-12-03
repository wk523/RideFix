import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';

class FullScreenImagePage extends StatelessWidget {
  final String imageUrl;

  const FullScreenImagePage({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Center(
        child: Hero(
          tag: imageUrl,
          child: PhotoView(
            imageProvider: NetworkImage(imageUrl),
            backgroundDecoration: const BoxDecoration(color: Colors.black),
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 3,
          ),
        ),
      ),
    );
  }
}
