import 'dart:math' as math;
import 'dart:typed_data';
import 'package:image/image.dart' as img;

import 'native_opencv.dart';

/// Plate Detector - Finds the 96-well plate region in the image.
/// Ported from Python prototype: files/plate_detector.py
class PlateDetector {
  /// Try to apply perspective correction using native OpenCV
  /// Returns corrected image if successful, null otherwise
  static img.Image? applyPerspectiveCorrection(img.Image image) {
    if (!NativeOpenCV.isAvailable) return null;

    try {
      // Convert image to RGBA bytes for OpenCV
      final rgba = _imageToRgba(image);

      // Use OpenCV to detect corners and warp
      final opencv = NativeOpenCV.instance;
      final result = opencv.correctPerspective(
        imageData: rgba,
        width: image.width,
        height: image.height,
      );

      if (result == null) return null;

      // Convert back to img.Image
      return _rgbaToImage(result.data, result.width, result.height);
    } catch (e) {
      print('[PlateDetector] Perspective correction failed: $e');
      return null;
    }
  }

  /// Detect plate corners for perspective correction
  /// Returns corner points if detected, null otherwise
  static PlateCorners? detectCorners(img.Image image) {
    if (!NativeOpenCV.isAvailable) return null;

    try {
      final rgba = _imageToRgba(image);
      final opencv = NativeOpenCV.instance;

      return opencv.detectPlateCorners(
        imageData: rgba,
        width: image.width,
        height: image.height,
      );
    } catch (e) {
      print('[PlateDetector] Corner detection failed: $e');
      return null;
    }
  }

  /// Convert img.Image to RGBA Uint8List
  static Uint8List _imageToRgba(img.Image image) {
    final data = Uint8List(image.width * image.height * 4);
    var idx = 0;

    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        data[idx++] = pixel.r.toInt();
        data[idx++] = pixel.g.toInt();
        data[idx++] = pixel.b.toInt();
        data[idx++] = pixel.a.toInt();
      }
    }

    return data;
  }

  /// Convert RGBA Uint8List to img.Image
  static img.Image _rgbaToImage(Uint8List data, int width, int height) {
    final image = img.Image(width: width, height: height);
    var idx = 0;

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final r = data[idx++];
        final g = data[idx++];
        final b = data[idx++];
        final a = data[idx++];
        image.setPixelRgba(x, y, r, g, b, a);
      }
    }

    return image;
  }

  /// Ensure image is in correct orientation (landscape for 96-well plate)
  /// 96-well plate should be landscape (width > height, aspect ~1.5)
  static img.Image ensureCorrectOrientation(img.Image image) {
    // If image is portrait (height > width), rotate 90 degrees
    if (image.height > image.width) {
      return img.copyRotate(image, angle: 90);
    }

    // Check aspect ratio - if too square, try rotation
    final aspect = image.width / image.height;
    if (aspect < 1.2) {
      // Nearly square image - rotate to get landscape orientation
      return img.copyRotate(image, angle: 90);
    }

    return image;
  }

  /// Enhanced normalization with CLAHE preprocessing
  /// Returns normalized image if successful, null otherwise
  static img.Image? applyEnhancedNormalization(img.Image image) {
    if (!NativeOpenCV.isAvailable) return null;

    try {
      final rgba = _imageToRgba(image);
      final opencv = NativeOpenCV.instance;

      final result = opencv.normalizeAndDetectPlate(
        imageData: rgba,
        width: image.width,
        height: image.height,
      );

      if (result == null) return null;

      return _rgbaToImage(result.data, result.width, result.height);
    } catch (e) {
      print('[PlateDetector] Enhanced normalization failed: $e');
      return null;
    }
  }

  /// Detect the microplate region and return a cropped, aligned image.
  ///
  /// Strategy:
  /// 0. Try enhanced normalization with CLAHE (most robust, lighting-independent)
  /// 1. Try perspective correction (fallback if CLAHE fails)
  /// 2. Try color-based detection (finds actual wells)
  /// 3. Fallback to edge-based detection (finds plate frame)
  /// 4. Last resort: center crop with expected aspect ratio
  static img.Image detectPlate(img.Image image) {
    // Strategy 0: Try enhanced normalization with CLAHE (Phase 3.5)
    final normalized = applyEnhancedNormalization(image);
    if (normalized != null) {
      print('[PlateDetector] Enhanced normalization (CLAHE) applied successfully');
      // After normalization, apply color-based detection for fine-tuning
      final colorBounds = _findPlateBoundsByColor(normalized);
      if (colorBounds != null) {
        final (x, y, w, h) = colorBounds;
        final aspect = w / h;
        if (aspect > 1.1 && aspect < 2.0) {
          final plateCrop = img.copyCrop(normalized, x: x, y: y, width: w, height: h);
          return _cropToWellAreaLight(plateCrop);
        }
      }
      return normalized;
    }

    // Strategy 1: Try perspective correction with OpenCV (fallback)
    final corrected = applyPerspectiveCorrection(image);
    if (corrected != null) {
      print('[PlateDetector] Perspective correction applied successfully');
      // After perspective correction, apply color-based detection
      final colorBounds = _findPlateBoundsByColor(corrected);
      if (colorBounds != null) {
        final (x, y, w, h) = colorBounds;
        final aspect = w / h;
        if (aspect > 1.1 && aspect < 2.0) {
          final plateCrop = img.copyCrop(corrected, x: x, y: y, width: w, height: h);
          return _cropToWellAreaLight(plateCrop);
        }
      }
      return corrected;
    }

    // Strategy 2: Color-based detection (finds actual well area directly)
    // This is the most accurate because it looks for pink/purple well colors
    final colorBounds = _findPlateBoundsByColor(image);
    if (colorBounds != null) {
      final (x, y, w, h) = colorBounds;
      final aspect = w / h;
      if (aspect > 1.1 && aspect < 2.0) {
        // Color detection may still include some margin, apply light crop
        final plateCrop = img.copyCrop(image, x: x, y: y, width: w, height: h);
        return _cropToWellAreaLight(plateCrop);
      }
    }

    // Strategy 3: Edge-based detection (finds plate frame)
    final gray = img.grayscale(image);
    final blurred = img.gaussianBlur(gray, radius: 3);
    final edges = _sobelEdgeDetection(blurred);
    final bounds = _findPlateBounds(edges, image.width, image.height);

    if (bounds != null) {
      final (x, y, w, h) = bounds;
      final aspect = w / h;
      if (aspect > 1.1 && aspect < 2.0) {
        // Edge detection finds plate frame - need to crop inward to well area
        final plateCrop = img.copyCrop(image, x: x, y: y, width: w, height: h);
        return _cropToWellArea(plateCrop);
      }
    }

    // Strategy 4: Center crop with expected aspect ratio
    final centerCrop = _centerCropWithAspect(image);
    return _cropToWellArea(centerCrop);
  }

  /// Light crop for color-based detection (already fairly accurate)
  static img.Image _cropToWellAreaLight(img.Image plate) {
    final w = plate.width;
    final h = plate.height;

    // Light margins - color detection already finds wells
    final leftMargin = (w * 0.02).toInt();
    final topMargin = (h * 0.03).toInt();
    final rightMargin = (w * 0.02).toInt();
    final bottomMargin = (h * 0.03).toInt();

    final newX = leftMargin;
    final newY = topMargin;
    final newW = w - leftMargin - rightMargin;
    final newH = h - topMargin - bottomMargin;

    if (newW < w * 0.8 || newH < h * 0.8) {
      return plate;
    }

    return img.copyCrop(plate, x: newX, y: newY, width: newW, height: newH);
  }

  /// Crop inward to just the well area (removing plate frame margins)
  /// Based on Python grid fitting results: origin=(91,116) on 1489x1025 plate
  /// Python well grid spans: X=91-1331 (6-89%), Y=116-903 (11-88%)
  static img.Image _cropToWellArea(img.Image plate) {
    final w = plate.width;
    final h = plate.height;

    // Calculate margins based on Python's actual grid fitting results
    // Use symmetric margins to prevent grid sampling outside plate
    final leftMargin = (w * 0.05).toInt();    // 5% from left
    final topMargin = (h * 0.10).toInt();     // 10% from top
    final rightMargin = (w * 0.05).toInt();   // 5% from right (symmetric with left)
    final bottomMargin = (h * 0.10).toInt();  // 10% from bottom

    final newX = leftMargin;
    final newY = topMargin;
    final newW = w - leftMargin - rightMargin;
    final newH = h - topMargin - bottomMargin;

    // Ensure dimensions are valid
    if (newW < w * 0.7 || newH < h * 0.7) {
      // Margins too aggressive, return original
      return plate;
    }

    return img.copyCrop(plate, x: newX, y: newY, width: newW, height: newH);
  }

  /// Sobel edge detection
  static img.Image _sobelEdgeDetection(img.Image gray) {
    final result = img.Image(width: gray.width, height: gray.height);

    // Sobel kernels
    const sobelX = [
      [-1, 0, 1],
      [-2, 0, 2],
      [-1, 0, 1]
    ];
    const sobelY = [
      [-1, -2, -1],
      [0, 0, 0],
      [1, 2, 1]
    ];

    for (var y = 1; y < gray.height - 1; y++) {
      for (var x = 1; x < gray.width - 1; x++) {
        var gx = 0.0;
        var gy = 0.0;

        for (var ky = -1; ky <= 1; ky++) {
          for (var kx = -1; kx <= 1; kx++) {
            final pixel = gray.getPixel(x + kx, y + ky);
            final val = pixel.r.toDouble();
            gx += val * sobelX[ky + 1][kx + 1];
            gy += val * sobelY[ky + 1][kx + 1];
          }
        }

        final magnitude = math.sqrt(gx * gx + gy * gy).clamp(0, 255).toInt();
        result.setPixelRgb(x, y, magnitude, magnitude, magnitude);
      }
    }

    return result;
  }

  /// Find plate bounds using edge projection analysis
  static (int, int, int, int)? _findPlateBounds(img.Image edges, int w, int h) {
    // Compute horizontal and vertical projections
    final hProj = List<double>.filled(h, 0);
    final vProj = List<double>.filled(w, 0);

    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final val = edges.getPixel(x, y).r.toDouble();
        hProj[y] += val;
        vProj[x] += val;
      }
    }

    // Normalize
    final maxH = hProj.reduce(math.max);
    final maxV = vProj.reduce(math.max);
    if (maxH > 0) {
      for (var i = 0; i < h; i++) {
        hProj[i] /= maxH;
      }
    }
    if (maxV > 0) {
      for (var i = 0; i < w; i++) {
        vProj[i] /= maxV;
      }
    }

    // Find boundaries using threshold
    const threshold = 0.15;

    // Find top boundary
    var top = 0;
    for (var y = 0; y < h ~/ 4; y++) {
      if (hProj[y] > threshold) {
        top = y;
        break;
      }
    }

    // Find bottom boundary
    var bottom = h - 1;
    for (var y = h - 1; y > h * 3 ~/ 4; y--) {
      if (hProj[y] > threshold) {
        bottom = y;
        break;
      }
    }

    // Find left boundary
    var left = 0;
    for (var x = 0; x < w ~/ 4; x++) {
      if (vProj[x] > threshold) {
        left = x;
        break;
      }
    }

    // Find right boundary
    var right = w - 1;
    for (var x = w - 1; x > w * 3 ~/ 4; x--) {
      if (vProj[x] > threshold) {
        right = x;
        break;
      }
    }

    // Add some padding
    final pad = math.min(w, h) ~/ 50;
    left = math.max(0, left - pad);
    top = math.max(0, top - pad);
    right = math.min(w - 1, right + pad);
    bottom = math.min(h - 1, bottom + pad);

    final cropW = right - left;
    final cropH = bottom - top;

    if (cropW < w * 0.5 || cropH < h * 0.5) {
      return null; // Too small, probably failed
    }

    return (left, top, cropW, cropH);
  }

  /// Find plate bounds by detecting colored wells
  /// This directly finds the well area (not the plate frame)
  static (int, int, int, int)? _findPlateBoundsByColor(img.Image image) {
    final w = image.width;
    final h = image.height;

    // Find pixels that could be wells (pink or purple)
    final wellPixels = <(int, int)>[];

    for (var y = 0; y < h; y += 3) { // Sample every 3rd pixel
      for (var x = 0; x < w; x += 3) {
        final pixel = image.getPixel(x, y);
        final r = pixel.r.toDouble();
        final g = pixel.g.toDouble();
        final b = pixel.b.toDouble();

        // Check if pixel is pink-ish or purple-ish (well colors)
        final hsv = _rgbToHsv(r, g, b);
        final hue = hsv.$1;
        final sat = hsv.$2;
        final val = hsv.$3;

        // Skip very bright (likely reflection) or very dark pixels
        if (val > 250 || val < 50) continue;

        // Pink/Growth: pinkish color (low-medium saturation, reddish tint)
        // Looser criteria to catch more pink wells
        final isPink = sat > 15 && sat < 100 && r > g * 0.9 && r > b * 0.8 && r > 130;

        // Purple/Inhibition: purple/blue color (medium-high saturation, purple hue)
        // Hue 120-175 covers blue-violet-purple in 0-179 scale
        final isPurple = sat > 50 && hue >= 115 && hue <= 178 && val > 60;

        if (isPink || isPurple) {
          wellPixels.add((x, y));
        }
      }
    }

    if (wellPixels.length < 100) {
      return null;
    }

    // Find bounding box of well pixels
    var minX = w, maxX = 0, minY = h, maxY = 0;
    for (final (x, y) in wellPixels) {
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }

    // Add small padding (one well radius approximately)
    final estimatedCellW = (maxX - minX) / 12;
    final estimatedCellH = (maxY - minY) / 8;
    final padX = (estimatedCellW * 0.3).toInt();
    final padY = (estimatedCellH * 0.3).toInt();

    minX = math.max(0, minX - padX);
    minY = math.max(0, minY - padY);
    maxX = math.min(w - 1, maxX + padX);
    maxY = math.min(h - 1, maxY + padY);

    return (minX, minY, maxX - minX, maxY - minY);
  }

  /// Center crop with expected 96-well plate aspect ratio
  static img.Image _centerCropWithAspect(img.Image image) {
    final w = image.width;
    final h = image.height;

    // Expected aspect ratio: 1.5 (127.76mm x 85.48mm)
    const targetAspect = 1.5;
    final currentAspect = w / h;

    int cropX, cropY, cropW, cropH;

    if (currentAspect > targetAspect) {
      // Image is too wide, crop sides
      cropH = h;
      cropW = (h * targetAspect).toInt();
      cropX = (w - cropW) ~/ 2;
      cropY = 0;
    } else {
      // Image is too tall, crop top/bottom
      cropW = w;
      cropH = (w / targetAspect).toInt();
      cropX = 0;
      cropY = (h - cropH) ~/ 2;
    }

    // Add larger margin inward to account for plate frame
    // Based on Python analysis: plate frame takes ~6-10% on each side
    final marginX = (cropW * 0.08).toInt();
    final marginY = (cropH * 0.10).toInt();

    return img.copyCrop(
      image,
      x: cropX + marginX,
      y: cropY + marginY,
      width: cropW - 2 * marginX,
      height: cropH - 2 * marginY,
    );
  }

  /// Convert RGB to HSV (H: 0-179, S: 0-255, V: 0-255)
  static (double, double, double) _rgbToHsv(double r, double g, double b) {
    final rNorm = r / 255.0;
    final gNorm = g / 255.0;
    final bNorm = b / 255.0;

    final maxVal = math.max(rNorm, math.max(gNorm, bNorm));
    final minVal = math.min(rNorm, math.min(gNorm, bNorm));
    final delta = maxVal - minVal;

    final v = maxVal * 255;

    double s;
    if (maxVal == 0) {
      s = 0;
    } else {
      s = (delta / maxVal) * 255;
    }

    double h;
    if (delta == 0) {
      h = 0;
    } else if (maxVal == rNorm) {
      h = 60 * (((gNorm - bNorm) / delta) % 6);
    } else if (maxVal == gNorm) {
      h = 60 * (((bNorm - rNorm) / delta) + 2);
    } else {
      h = 60 * (((rNorm - gNorm) / delta) + 4);
    }

    if (h < 0) h += 360;
    h = h / 2; // Convert to 0-179 scale

    return (h, s, v);
  }
}
