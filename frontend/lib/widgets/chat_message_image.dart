import 'package:flutter/material.dart';

/// Tappable chat photo with loading + error states. Tapping opens the image
/// full-screen. Used by both alumni and admin message bubbles.
class ChatMessageImage extends StatelessWidget {
  final String imageUrl;
  final double maxWidth;

  const ChatMessageImage({
    super.key,
    required this.imageUrl,
    this.maxWidth = 220,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showDialog(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: Stack(
            alignment: Alignment.topRight,
            children: [
              InteractiveViewer(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Padding(
                      padding: EdgeInsets.all(32),
                      child: Icon(Icons.broken_image_outlined,
                          color: Colors.white70, size: 48),
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Close',
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          imageUrl,
          width: maxWidth,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return SizedBox(
              width: maxWidth,
              height: 140,
              child: Center(
                child: CircularProgressIndicator(
                  value: progress.expectedTotalBytes != null
                      ? progress.cumulativeBytesLoaded /
                          progress.expectedTotalBytes!
                      : null,
                  strokeWidth: 2,
                ),
              ),
            );
          },
          errorBuilder: (_, __, ___) => const SizedBox(
            width: 220,
            height: 90,
            child: Center(
              child: Icon(Icons.broken_image_outlined, size: 32),
            ),
          ),
        ),
      ),
    );
  }
}
