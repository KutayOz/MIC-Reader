import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

/// Circle detected by OpenCV HoughCircles
class DetectedCircle {
  final double x;
  final double y;
  final double radius;

  DetectedCircle({required this.x, required this.y, required this.radius});

  @override
  String toString() => 'Circle(x: ${x.toStringAsFixed(1)}, y: ${y.toStringAsFixed(1)}, r: ${radius.toStringAsFixed(1)})';
}

/// Plate corners detected for perspective correction
class PlateCorners {
  final double x1, y1; // Top-left
  final double x2, y2; // Top-right
  final double x3, y3; // Bottom-right
  final double x4, y4; // Bottom-left

  PlateCorners({
    required this.x1, required this.y1,
    required this.x2, required this.y2,
    required this.x3, required this.y3,
    required this.x4, required this.y4,
  });

  @override
  String toString() => 'PlateCorners(TL=($x1,$y1), TR=($x2,$y2), BR=($x3,$y3), BL=($x4,$y4))';
}

/// Result of perspective warp operation
class WarpedImage {
  final Uint8List data;
  final int width;
  final int height;

  WarpedImage({required this.data, required this.width, required this.height});
}

/// Native circle structure matching C++ struct
final class NativeCircle extends Struct {
  @Float()
  external double x;

  @Float()
  external double y;

  @Float()
  external double radius;
}

/// Native detection result structure matching C++ struct
final class NativeCircleDetectionResult extends Struct {
  external Pointer<NativeCircle> circles;

  @Int32()
  external int count;

  @Int32()
  external int error;
}

/// Native plate corners structure matching C++ struct
final class NativePlateCorners extends Struct {
  @Float()
  external double x1;
  @Float()
  external double y1;
  @Float()
  external double x2;
  @Float()
  external double y2;
  @Float()
  external double x3;
  @Float()
  external double y3;
  @Float()
  external double x4;
  @Float()
  external double y4;
  @Int32()
  external int valid;
}

/// Native warp result structure matching C++ struct
final class NativeWarpResult extends Struct {
  external Pointer<Uint8> imageData;

  @Int32()
  external int width;

  @Int32()
  external int height;

  @Int32()
  external int error;
}

/// FFI type definitions
typedef DetectCirclesNative = Pointer<NativeCircleDetectionResult> Function(
  Pointer<Uint8> imageData,
  Int32 width,
  Int32 height,
  Int32 minRadius,
  Int32 maxRadius,
  Double dp,
  Double minDist,
  Double param1,
  Double param2,
);

typedef DetectCirclesDart = Pointer<NativeCircleDetectionResult> Function(
  Pointer<Uint8> imageData,
  int width,
  int height,
  int minRadius,
  int maxRadius,
  double dp,
  double minDist,
  double param1,
  double param2,
);

typedef DetectCirclesMultiPassNative = Pointer<NativeCircleDetectionResult> Function(
  Pointer<Uint8> imageData,
  Int32 width,
  Int32 height,
  Int32 minRadius,
  Int32 maxRadius,
);

typedef DetectCirclesMultiPassDart = Pointer<NativeCircleDetectionResult> Function(
  Pointer<Uint8> imageData,
  int width,
  int height,
  int minRadius,
  int maxRadius,
);

typedef FreeCircleResultNative = Void Function(Pointer<NativeCircleDetectionResult> result);
typedef FreeCircleResultDart = void Function(Pointer<NativeCircleDetectionResult> result);

typedef GetOpenCVVersionNative = Pointer<Utf8> Function();
typedef GetOpenCVVersionDart = Pointer<Utf8> Function();

// Perspective correction FFI types
typedef DetectPlateCornersNative = Pointer<NativePlateCorners> Function(
  Pointer<Uint8> imageData,
  Int32 width,
  Int32 height,
);

typedef DetectPlateCornersDart = Pointer<NativePlateCorners> Function(
  Pointer<Uint8> imageData,
  int width,
  int height,
);

typedef WarpPerspectiveNative = Pointer<NativeWarpResult> Function(
  Pointer<Uint8> imageData,
  Int32 width,
  Int32 height,
  Float srcX1, Float srcY1,
  Float srcX2, Float srcY2,
  Float srcX3, Float srcY3,
  Float srcX4, Float srcY4,
  Int32 dstWidth,
  Int32 dstHeight,
);

typedef WarpPerspectiveDart = Pointer<NativeWarpResult> Function(
  Pointer<Uint8> imageData,
  int width,
  int height,
  double srcX1, double srcY1,
  double srcX2, double srcY2,
  double srcX3, double srcY3,
  double srcX4, double srcY4,
  int dstWidth,
  int dstHeight,
);

typedef FreePlateCornersNative = Void Function(Pointer<NativePlateCorners> corners);
typedef FreeePlateCornersDart = void Function(Pointer<NativePlateCorners> corners);

typedef FreeWarpResultNative = Void Function(Pointer<NativeWarpResult> result);
typedef FreeWarpResultDart = void Function(Pointer<NativeWarpResult> result);

// Normalization FFI types
typedef NormalizeAndDetectPlateNative = Pointer<NativeWarpResult> Function(
  Pointer<Uint8> imageData,
  Int32 width,
  Int32 height,
);

typedef NormalizeAndDetectPlateDart = Pointer<NativeWarpResult> Function(
  Pointer<Uint8> imageData,
  int width,
  int height,
);

typedef FreeNormalizationResultNative = Void Function(Pointer<NativeWarpResult> result);
typedef FreeNormalizationResultDart = void Function(Pointer<NativeWarpResult> result);

// Ultra-robust well detection FFI types
typedef DetectWellsRobustNative = Pointer<NativeCircleDetectionResult> Function(
  Pointer<Uint8> imageData,
  Int32 width,
  Int32 height,
);

typedef DetectWellsRobustDart = Pointer<NativeCircleDetectionResult> Function(
  Pointer<Uint8> imageData,
  int width,
  int height,
);

/// Native OpenCV wrapper for circle detection
class NativeOpenCV {
  static NativeOpenCV? _instance;
  static bool _initialized = false;
  static String? _initError;

  late final DynamicLibrary _lib;
  late final DetectCirclesDart _detectCircles;
  late final DetectCirclesMultiPassDart _detectCirclesMultiPass;
  late final FreeCircleResultDart _freeCircleResult;
  late final GetOpenCVVersionDart _getOpenCVVersion;
  // Perspective correction functions
  late final DetectPlateCornersDart _detectPlateCorners;
  late final WarpPerspectiveDart _warpPerspective;
  late final FreeePlateCornersDart _freePlateCorners;
  late final FreeWarpResultDart _freeWarpResult;
  // Normalization functions
  late final NormalizeAndDetectPlateDart _normalizeAndDetectPlate;
  late final FreeNormalizationResultDart _freeNormalizationResult;
  // Ultra-robust well detection
  late final DetectWellsRobustDart _detectWellsRobust;

  NativeOpenCV._() {
    try {
      if (Platform.isAndroid) {
        _lib = DynamicLibrary.open('libnative_opencv.so');
      } else if (Platform.isIOS) {
        _lib = DynamicLibrary.process();
      } else {
        throw UnsupportedError('Platform not supported');
      }

      _detectCircles = _lib
          .lookup<NativeFunction<DetectCirclesNative>>('detectCircles')
          .asFunction<DetectCirclesDart>();

      _detectCirclesMultiPass = _lib
          .lookup<NativeFunction<DetectCirclesMultiPassNative>>('detectCirclesMultiPass')
          .asFunction<DetectCirclesMultiPassDart>();

      _freeCircleResult = _lib
          .lookup<NativeFunction<FreeCircleResultNative>>('freeCircleResult')
          .asFunction<FreeCircleResultDart>();

      _getOpenCVVersion = _lib
          .lookup<NativeFunction<GetOpenCVVersionNative>>('getOpenCVVersion')
          .asFunction<GetOpenCVVersionDart>();

      // Perspective correction functions
      _detectPlateCorners = _lib
          .lookup<NativeFunction<DetectPlateCornersNative>>('detectPlateCorners')
          .asFunction<DetectPlateCornersDart>();

      _warpPerspective = _lib
          .lookup<NativeFunction<WarpPerspectiveNative>>('warpPerspective')
          .asFunction<WarpPerspectiveDart>();

      _freePlateCorners = _lib
          .lookup<NativeFunction<FreePlateCornersNative>>('freePlateCorners')
          .asFunction<FreeePlateCornersDart>();

      _freeWarpResult = _lib
          .lookup<NativeFunction<FreeWarpResultNative>>('freeWarpResult')
          .asFunction<FreeWarpResultDart>();

      // Normalization functions
      _normalizeAndDetectPlate = _lib
          .lookup<NativeFunction<NormalizeAndDetectPlateNative>>('normalizeAndDetectPlate')
          .asFunction<NormalizeAndDetectPlateDart>();

      _freeNormalizationResult = _lib
          .lookup<NativeFunction<FreeNormalizationResultNative>>('freeNormalizationResult')
          .asFunction<FreeNormalizationResultDart>();

      // Ultra-robust well detection
      _detectWellsRobust = _lib
          .lookup<NativeFunction<DetectWellsRobustNative>>('detectWellsRobust')
          .asFunction<DetectWellsRobustDart>();

      _initialized = true;
    } catch (e) {
      _initError = e.toString();
      _initialized = false;
    }
  }

  /// Get singleton instance
  static NativeOpenCV get instance {
    _instance ??= NativeOpenCV._();
    return _instance!;
  }

  /// Check if native library is available
  /// This triggers initialization if not already done
  static bool get isAvailable {
    // Trigger initialization if not done yet
    if (_instance == null) {
      _instance = NativeOpenCV._();
    }
    return _initialized;
  }

  /// Get initialization error if any
  static String? get initializationError {
    // Trigger initialization if not done yet
    if (_instance == null) {
      _instance = NativeOpenCV._();
    }
    return _initError;
  }

  /// Get OpenCV version
  String? getVersion() {
    if (!_initialized) return null;
    try {
      final versionPtr = _getOpenCVVersion();
      return versionPtr.toDartString();
    } catch (e) {
      return null;
    }
  }

  /// Detect circles using Hough Transform with custom parameters
  List<DetectedCircle>? detectCircles({
    required Uint8List imageData,
    required int width,
    required int height,
    required int minRadius,
    required int maxRadius,
    double dp = 1.2,
    double minDist = 50,
    double param1 = 100,
    double param2 = 30,
  }) {
    if (!_initialized) return null;

    // Allocate native memory for image data
    final nativeImageData = calloc<Uint8>(imageData.length);
    try {
      // Copy image data to native memory
      for (var i = 0; i < imageData.length; i++) {
        nativeImageData[i] = imageData[i];
      }

      // Call native function
      final result = _detectCircles(
        nativeImageData,
        width,
        height,
        minRadius,
        maxRadius,
        dp,
        minDist,
        param1,
        param2,
      );

      if (result == nullptr || result.ref.error != 0) {
        if (result != nullptr) _freeCircleResult(result);
        return null;
      }

      // Extract circles from result
      final circles = <DetectedCircle>[];
      for (var i = 0; i < result.ref.count; i++) {
        final c = result.ref.circles[i];
        circles.add(DetectedCircle(x: c.x, y: c.y, radius: c.radius));
      }

      // Free native memory
      _freeCircleResult(result);

      return circles;
    } finally {
      calloc.free(nativeImageData);
    }
  }

  /// Detect circles using multiple parameter combinations (like Python implementation)
  List<DetectedCircle>? detectCirclesMultiPass({
    required Uint8List imageData,
    required int width,
    required int height,
    required int minRadius,
    required int maxRadius,
  }) {
    if (!_initialized) return null;

    // Allocate native memory for image data
    final nativeImageData = calloc<Uint8>(imageData.length);
    try {
      // Copy image data to native memory
      for (var i = 0; i < imageData.length; i++) {
        nativeImageData[i] = imageData[i];
      }

      // Call native function
      final result = _detectCirclesMultiPass(
        nativeImageData,
        width,
        height,
        minRadius,
        maxRadius,
      );

      if (result == nullptr || result.ref.error != 0) {
        if (result != nullptr) _freeCircleResult(result);
        return null;
      }

      // Extract circles from result
      final circles = <DetectedCircle>[];
      for (var i = 0; i < result.ref.count; i++) {
        final c = result.ref.circles[i];
        circles.add(DetectedCircle(x: c.x, y: c.y, radius: c.radius));
      }

      // Free native memory
      _freeCircleResult(result);

      return circles;
    } finally {
      calloc.free(nativeImageData);
    }
  }

  /// Detect plate corners for perspective correction
  /// Returns 4 corners (TL, TR, BR, BL) if detected, null otherwise
  PlateCorners? detectPlateCorners({
    required Uint8List imageData,
    required int width,
    required int height,
  }) {
    if (!_initialized) return null;

    // Allocate native memory for image data
    final nativeImageData = calloc<Uint8>(imageData.length);
    try {
      // Copy image data to native memory
      for (var i = 0; i < imageData.length; i++) {
        nativeImageData[i] = imageData[i];
      }

      // Call native function
      final result = _detectPlateCorners(
        nativeImageData,
        width,
        height,
      );

      if (result == nullptr || result.ref.valid == 0) {
        if (result != nullptr) _freePlateCorners(result);
        return null;
      }

      // Extract corners
      final corners = PlateCorners(
        x1: result.ref.x1, y1: result.ref.y1,
        x2: result.ref.x2, y2: result.ref.y2,
        x3: result.ref.x3, y3: result.ref.y3,
        x4: result.ref.x4, y4: result.ref.y4,
      );

      // Free native memory
      _freePlateCorners(result);

      return corners;
    } finally {
      calloc.free(nativeImageData);
    }
  }

  /// Apply perspective correction to an image
  /// srcCorners: detected plate corners
  /// dstWidth, dstHeight: output image dimensions
  WarpedImage? warpPerspective({
    required Uint8List imageData,
    required int width,
    required int height,
    required PlateCorners srcCorners,
    required int dstWidth,
    required int dstHeight,
  }) {
    if (!_initialized) return null;

    // Allocate native memory for image data
    final nativeImageData = calloc<Uint8>(imageData.length);
    try {
      // Copy image data to native memory
      for (var i = 0; i < imageData.length; i++) {
        nativeImageData[i] = imageData[i];
      }

      // Call native function
      final result = _warpPerspective(
        nativeImageData,
        width,
        height,
        srcCorners.x1, srcCorners.y1,
        srcCorners.x2, srcCorners.y2,
        srcCorners.x3, srcCorners.y3,
        srcCorners.x4, srcCorners.y4,
        dstWidth,
        dstHeight,
      );

      if (result == nullptr || result.ref.error != 0) {
        if (result != nullptr) _freeWarpResult(result);
        return null;
      }

      // Copy warped image data
      final dataSize = result.ref.width * result.ref.height * 4;
      final warpedData = Uint8List(dataSize);
      for (var i = 0; i < dataSize; i++) {
        warpedData[i] = result.ref.imageData[i];
      }

      final warpedImage = WarpedImage(
        data: warpedData,
        width: result.ref.width,
        height: result.ref.height,
      );

      // Free native memory
      _freeWarpResult(result);

      return warpedImage;
    } finally {
      calloc.free(nativeImageData);
    }
  }

  /// Convenience method: detect corners and warp in one call
  /// Returns warped image data if successful, null otherwise
  WarpedImage? correctPerspective({
    required Uint8List imageData,
    required int width,
    required int height,
    int? outputWidth,
    int? outputHeight,
  }) {
    // Detect corners
    final corners = detectPlateCorners(
      imageData: imageData,
      width: width,
      height: height,
    );

    if (corners == null) return null;

    // Calculate output dimensions if not specified
    // Use 96-well plate aspect ratio (1.5:1)
    final dstWidth = outputWidth ?? width;
    final dstHeight = outputHeight ?? (dstWidth / 1.5).round();

    // Apply warp
    return warpPerspective(
      imageData: imageData,
      width: width,
      height: height,
      srcCorners: corners,
      dstWidth: dstWidth,
      dstHeight: dstHeight,
    );
  }

  /// Enhanced plate normalization with CLAHE preprocessing
  /// Applies:
  /// 1. CLAHE (Contrast Limited Adaptive Histogram Equalization)
  /// 2. Bilateral filter for noise reduction
  /// 3. Adaptive thresholding
  /// 4. Contour detection for plate rectangle
  /// 5. Perspective warp
  /// Returns normalized image data if successful, null otherwise
  WarpedImage? normalizeAndDetectPlate({
    required Uint8List imageData,
    required int width,
    required int height,
  }) {
    if (!_initialized) return null;

    // Allocate native memory for image data
    final nativeImageData = calloc<Uint8>(imageData.length);
    try {
      // Copy image data to native memory
      for (var i = 0; i < imageData.length; i++) {
        nativeImageData[i] = imageData[i];
      }

      // Call native function
      final result = _normalizeAndDetectPlate(
        nativeImageData,
        width,
        height,
      );

      if (result == nullptr || result.ref.error != 0) {
        if (result != nullptr) _freeNormalizationResult(result);
        return null;
      }

      // Copy normalized image data
      final dataSize = result.ref.width * result.ref.height * 4;
      final normalizedData = Uint8List(dataSize);
      for (var i = 0; i < dataSize; i++) {
        normalizedData[i] = result.ref.imageData[i];
      }

      final normalizedImage = WarpedImage(
        data: normalizedData,
        width: result.ref.width,
        height: result.ref.height,
      );

      // Free native memory
      _freeNormalizationResult(result);

      return normalizedImage;
    } finally {
      calloc.free(nativeImageData);
    }
  }

  /// Ultra-robust well detection with full enhancement pipeline
  /// Applies:
  /// 1. Auto white balance
  /// 2. Auto gamma correction
  /// 3. CLAHE
  /// 4. Bilateral filter
  /// 5. Multi-scale, multi-parameter HoughCircles
  /// 6. Color validation
  /// 7. Clustering and merging
  List<DetectedCircle>? detectWellsRobust({
    required Uint8List imageData,
    required int width,
    required int height,
  }) {
    if (!_initialized) return null;

    // Allocate native memory for image data
    final nativeImageData = calloc<Uint8>(imageData.length);
    try {
      // Copy image data to native memory
      for (var i = 0; i < imageData.length; i++) {
        nativeImageData[i] = imageData[i];
      }

      // Call native function
      final result = _detectWellsRobust(
        nativeImageData,
        width,
        height,
      );

      if (result == nullptr || result.ref.error != 0) {
        if (result != nullptr) _freeCircleResult(result);
        return null;
      }

      // Extract circles from result
      final circles = <DetectedCircle>[];
      for (var i = 0; i < result.ref.count; i++) {
        final c = result.ref.circles[i];
        circles.add(DetectedCircle(x: c.x, y: c.y, radius: c.radius));
      }

      // Free native memory
      _freeCircleResult(result);

      return circles;
    } finally {
      calloc.free(nativeImageData);
    }
  }
}
