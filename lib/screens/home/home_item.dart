import 'package:flutter/material.dart';
import 'dart:ui';

class HomeItem extends StatefulWidget {
  final String title;
  final Color color;
  final String? imagePath;
  final String? lastClicked;
  final Function(String)? onTap;

  const HomeItem({
    super.key,
    required this.title,
    required this.color,
    this.imagePath,
    this.lastClicked,
    this.onTap,
  });

  @override
  State<HomeItem> createState() => _HomeItemState();
}

class _HomeItemState extends State<HomeItem> {
  @override
  Widget build(BuildContext context) {
    bool isSelected = widget.lastClicked == widget.title;
    Color overlayColor = isSelected
        ? Colors.green.withAlpha((0.4 * 255).round())
        : widget.color.withAlpha((0.3 * 255).round());

    return GestureDetector(
      onTap: () {
        final localContext = context;

        // Inform the parent
        widget.onTap?.call(widget.title);

        if (!localContext.mounted) return;

        ScaffoldMessenger.of(
          localContext,
        ).showSnackBar(SnackBar(content: Text('Saved: ${widget.title}')));
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildBackgroundImage(),
              Container(
                decoration: BoxDecoration(color: overlayColor),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 1.0, sigmaY: 1.0),
                  child: Container(
                    color: Colors.black.withAlpha((0.1 * 255).round()),
                  ),
                ),
              ),
              Center(
                child: Text(
                  widget.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        offset: Offset(1.0, 1.0),
                        blurRadius: 3.0,
                        color: Colors.black54,
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackgroundImage() {
    if (widget.imagePath != null) {
      // Use local asset image
      return Image.asset(
        widget.imagePath!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildFallbackImage();
        },
      );
    } else {
      // Use fallback image directly (no network dependency)
      return _buildFallbackImage();
    }
  }

  Widget _buildFallbackImage() {
    return Container(
      color: widget.color.withAlpha((0.3 * 255).round()),
      child: const Icon(
        Icons.image_not_supported,
        color: Colors.white,
        size: 40,
      ),
    );
  }
}
