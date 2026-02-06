import 'package:flutter/material.dart';

/// Overlay showing alignment guide for 96-well plate capture
/// Simplified version with drug row indicators
class PlateGuideOverlay extends StatelessWidget {
  final bool isLandscape;

  const PlateGuideOverlay({super.key, this.isLandscape = false});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Standard 96-well plate aspect ratio is ~1.5 (127.76mm x 85.48mm)
        const plateAspectRatio = 1.5;

        double guideWidth;
        double guideHeight;

        if (isLandscape) {
          // In landscape: plate is horizontal, so width > height
          guideHeight = constraints.maxHeight * 0.75;
          guideWidth = guideHeight * plateAspectRatio;

          // Make sure it fits in width
          if (guideWidth > constraints.maxWidth * 0.9) {
            guideWidth = constraints.maxWidth * 0.9;
            guideHeight = guideWidth / plateAspectRatio;
          }
        } else {
          // Portrait mode
          guideWidth = constraints.maxWidth * 0.85;
          guideHeight = guideWidth / plateAspectRatio;
        }

        // Center position
        final left = (constraints.maxWidth - guideWidth) / 2;
        final top = (constraints.maxHeight - guideHeight) / 2;

        return Stack(
          children: [
            // Semi-transparent overlay outside the guide
            Positioned.fill(
              child: CustomPaint(
                painter: _OverlayPainter(
                  guideRect: Rect.fromLTWH(left, top, guideWidth, guideHeight),
                ),
              ),
            ),

            // Plate outline - simple border
            Positioned(
              left: left,
              top: top,
              width: guideWidth,
              height: guideHeight,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.8),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),

            // Corner markers
            ..._buildCornerMarkers(left, top, guideWidth, guideHeight),

            // Drug row indicators (only in landscape)
            if (isLandscape) ...[
              // Top row indicator - Anidulafungin
              Positioned(
                left: left - 8,
                top: top + 8,
                child: _DrugRowIndicator(
                  rowLabel: 'A',
                  drugCode: 'AND',
                  drugName: 'Anidulafungin',
                  isTop: true,
                ),
              ),

              // Bottom row indicator - Amphotericin B
              Positioned(
                left: left - 8,
                bottom: constraints.maxHeight - top - guideHeight + 8,
                child: _DrugRowIndicator(
                  rowLabel: 'H',
                  drugCode: 'AMB',
                  drugName: 'Amphotericin B',
                  isTop: false,
                ),
              ),
            ],

            // Help text at bottom
            Positioned(
              left: 0,
              right: 0,
              bottom: top - 40,
              child: const _HelpText(),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _buildCornerMarkers(double left, double top, double width, double height) {
    const markerSize = 24.0;
    const markerThickness = 3.0;
    const color = Colors.white;

    return [
      // Top-left
      Positioned(
        left: left - markerThickness,
        top: top - markerThickness,
        child: _CornerMarker(
          size: markerSize,
          thickness: markerThickness,
          color: color,
          corner: _Corner.topLeft,
        ),
      ),
      // Top-right
      Positioned(
        left: left + width - markerSize + markerThickness,
        top: top - markerThickness,
        child: _CornerMarker(
          size: markerSize,
          thickness: markerThickness,
          color: color,
          corner: _Corner.topRight,
        ),
      ),
      // Bottom-left
      Positioned(
        left: left - markerThickness,
        top: top + height - markerSize + markerThickness,
        child: _CornerMarker(
          size: markerSize,
          thickness: markerThickness,
          color: color,
          corner: _Corner.bottomLeft,
        ),
      ),
      // Bottom-right
      Positioned(
        left: left + width - markerSize + markerThickness,
        top: top + height - markerSize + markerThickness,
        child: _CornerMarker(
          size: markerSize,
          thickness: markerThickness,
          color: color,
          corner: _Corner.bottomRight,
        ),
      ),
    ];
  }
}

/// Drug row indicator showing row label and drug name
class _DrugRowIndicator extends StatelessWidget {
  final String rowLabel;
  final String drugCode;
  final String drugName;
  final bool isTop;

  const _DrugRowIndicator({
    required this.rowLabel,
    required this.drugCode,
    required this.drugName,
    required this.isTop,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row label with arrow
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              rowLabel,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 6),
          const Icon(
            Icons.arrow_forward,
            color: Colors.white70,
            size: 12,
          ),
          const SizedBox(width: 6),
          // Drug info
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                drugCode,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                drugName,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Help text at the bottom of the overlay
class _HelpText extends StatelessWidget {
  const _HelpText();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          'Align plate within the frame',
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// Semi-transparent overlay painter
class _OverlayPainter extends CustomPainter {
  final Rect guideRect;

  _OverlayPainter({required this.guideRect});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    // Create path with hole for guide area
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(guideRect, const Radius.circular(8)))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

enum _Corner { topLeft, topRight, bottomLeft, bottomRight }

class _CornerMarker extends StatelessWidget {
  final double size;
  final double thickness;
  final Color color;
  final _Corner corner;

  const _CornerMarker({
    required this.size,
    required this.thickness,
    required this.color,
    required this.corner,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _CornerPainter(
          thickness: thickness,
          color: color,
          corner: corner,
        ),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final double thickness;
  final Color color;
  final _Corner corner;

  _CornerPainter({
    required this.thickness,
    required this.color,
    required this.corner,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();

    switch (corner) {
      case _Corner.topLeft:
        path.moveTo(0, size.height * 0.6);
        path.lineTo(0, 0);
        path.lineTo(size.width * 0.6, 0);
        break;
      case _Corner.topRight:
        path.moveTo(size.width * 0.4, 0);
        path.lineTo(size.width, 0);
        path.lineTo(size.width, size.height * 0.6);
        break;
      case _Corner.bottomLeft:
        path.moveTo(0, size.height * 0.4);
        path.lineTo(0, size.height);
        path.lineTo(size.width * 0.6, size.height);
        break;
      case _Corner.bottomRight:
        path.moveTo(size.width * 0.4, size.height);
        path.lineTo(size.width, size.height);
        path.lineTo(size.width, size.height * 0.4);
        break;
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
