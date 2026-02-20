import 'package:flutter/material.dart';

class HomeItem extends StatefulWidget {
  final String title;
  final Color color;
  final String? imagePath;
  final String? lastClicked;
  final Function(String)? onTap;
  final bool isHidden;

  const HomeItem({
    super.key,
    required this.title,
    required this.color,
    this.imagePath,
    this.lastClicked,
    this.onTap,
    this.isHidden = false,
  });

  @override
  State<HomeItem> createState() => _HomeItemState();
}

class _HomeItemState extends State<HomeItem> {
  @override
  Widget build(BuildContext context) {
    bool isSelected = widget.lastClicked == widget.title;

    return Opacity(
      opacity: widget.isHidden ? 0.45 : 1.0,
      child: GestureDetector(
        // Disable taps when hidden
        onTap: widget.isHidden
            ? null
            : () {
                final localContext = context;

                // Inform the parent
                widget.onTap?.call(widget.title);

                if (!localContext.mounted) return;
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
                // Light gradient overlay for text readability
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.2),
                        Colors.black.withValues(alpha: 0.5),
                      ],
                    ),
                  ),
                ),
                // Selected state indicator
                if (isSelected && !widget.isHidden)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.2),
                    ),
                  ),
                // Disabled overlay for hidden items
                if (widget.isHidden)
                  Positioned.fill(
                    child: Container(
                      color: Theme.of(context).disabledColor.withOpacity(0.25),
                    ),
                  ),
                Center(
                  child: Text(
                    widget.title,
                    style: TextStyle(
                      color: widget.isHidden
                          ? Theme.of(context).disabledColor
                          : Colors.white,
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
