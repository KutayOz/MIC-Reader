// native_opencv.cpp - Enhanced OpenCV wrapper for Flutter FFI
// Robust image processing for MIC plate well detection

#include <opencv2/opencv.hpp>
#include <opencv2/imgproc.hpp>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <algorithm>
#include <cmath>

extern "C" {

// ============================================================================
// Structures
// ============================================================================

struct Circle {
    float x;
    float y;
    float radius;
};

struct CircleDetectionResult {
    Circle* circles;
    int count;
    int error;
};

struct PlateCorners {
    float x1, y1;  // top-left
    float x2, y2;  // top-right
    float x3, y3;  // bottom-right
    float x4, y4;  // bottom-left
    int valid;
};

struct WarpResult {
    uint8_t* imageData;
    int width;
    int height;
    int error;
};

// ============================================================================
// Memory Management
// ============================================================================

__attribute__((visibility("default"))) __attribute__((used))
void freeCircleResult(CircleDetectionResult* result) {
    if (result != nullptr) {
        if (result->circles != nullptr) {
            free(result->circles);
        }
        free(result);
    }
}

__attribute__((visibility("default"))) __attribute__((used))
void freeWarpResult(WarpResult* result) {
    if (result != nullptr) {
        if (result->imageData != nullptr) {
            free(result->imageData);
        }
        free(result);
    }
}

__attribute__((visibility("default"))) __attribute__((used))
void freePlateCorners(PlateCorners* corners) {
    if (corners != nullptr) {
        free(corners);
    }
}

__attribute__((visibility("default"))) __attribute__((used))
void freeNormalizationResult(WarpResult* result) {
    freeWarpResult(result);
}

// ============================================================================
// Helper Functions
// ============================================================================

// Sort corners: TL, TR, BR, BL
static void sortCorners(std::vector<cv::Point2f>& corners) {
    if (corners.size() != 4) return;

    cv::Point2f center(0, 0);
    for (const auto& pt : corners) {
        center.x += pt.x;
        center.y += pt.y;
    }
    center.x /= 4;
    center.y /= 4;

    std::vector<cv::Point2f> topPoints, bottomPoints;
    for (const auto& pt : corners) {
        if (pt.y < center.y) {
            topPoints.push_back(pt);
        } else {
            bottomPoints.push_back(pt);
        }
    }

    if (topPoints.size() == 2 && bottomPoints.size() == 2) {
        std::sort(topPoints.begin(), topPoints.end(), [](const cv::Point2f& a, const cv::Point2f& b) {
            return a.x < b.x;
        });
        std::sort(bottomPoints.begin(), bottomPoints.end(), [](const cv::Point2f& a, const cv::Point2f& b) {
            return a.x < b.x;
        });

        corners[0] = topPoints[0];     // TL
        corners[1] = topPoints[1];     // TR
        corners[2] = bottomPoints[1];  // BR
        corners[3] = bottomPoints[0];  // BL
    }
}

// Auto white balance using Gray World assumption
static void autoWhiteBalance(cv::Mat& img) {
    std::vector<cv::Mat> channels;
    cv::split(img, channels);

    double avgB = cv::mean(channels[0])[0];
    double avgG = cv::mean(channels[1])[0];
    double avgR = cv::mean(channels[2])[0];
    double avgGray = (avgB + avgG + avgR) / 3.0;

    if (avgB > 0) channels[0] *= (avgGray / avgB);
    if (avgG > 0) channels[1] *= (avgGray / avgG);
    if (avgR > 0) channels[2] *= (avgGray / avgR);

    cv::merge(channels, img);
}

// Auto gamma correction
static void autoGamma(cv::Mat& img) {
    cv::Mat gray;
    cv::cvtColor(img, gray, cv::COLOR_BGR2GRAY);
    double meanVal = cv::mean(gray)[0];

    // Target mean brightness ~127
    double gamma = log(127.0 / 255.0) / log(meanVal / 255.0);
    gamma = std::max(0.5, std::min(2.5, gamma));  // Clamp gamma

    cv::Mat lut(1, 256, CV_8UC1);
    for (int i = 0; i < 256; i++) {
        lut.at<uchar>(i) = cv::saturate_cast<uchar>(pow(i / 255.0, gamma) * 255.0);
    }
    cv::LUT(img, lut, img);
}

// Apply CLAHE to L channel
static void applyCLAHE(cv::Mat& img, double clipLimit = 2.0) {
    cv::Mat lab;
    cv::cvtColor(img, lab, cv::COLOR_BGR2Lab);

    std::vector<cv::Mat> labChannels;
    cv::split(lab, labChannels);

    cv::Ptr<cv::CLAHE> clahe = cv::createCLAHE(clipLimit, cv::Size(8, 8));
    clahe->apply(labChannels[0], labChannels[0]);

    cv::merge(labChannels, lab);
    cv::cvtColor(lab, img, cv::COLOR_Lab2BGR);
}

// Unsharp mask for edge enhancement
static void unsharpMask(cv::Mat& img, double sigma = 1.0, double amount = 1.5) {
    cv::Mat blurred;
    cv::GaussianBlur(img, blurred, cv::Size(0, 0), sigma);
    cv::addWeighted(img, 1.0 + amount, blurred, -amount, 0, img);
}

// Create pink/purple mask for well detection
static cv::Mat createWellColorMask(const cv::Mat& bgr) {
    cv::Mat hsv;
    cv::cvtColor(bgr, hsv, cv::COLOR_BGR2HSV);

    // Pink mask: H=150-180 or 0-10, S=30-255, V=80-255
    cv::Mat pinkMask1, pinkMask2, pinkMask;
    cv::inRange(hsv, cv::Scalar(150, 30, 80), cv::Scalar(180, 255, 255), pinkMask1);
    cv::inRange(hsv, cv::Scalar(0, 30, 80), cv::Scalar(10, 255, 255), pinkMask2);
    pinkMask = pinkMask1 | pinkMask2;

    // Purple/Blue mask: H=100-150, S=30-255, V=50-255
    cv::Mat purpleMask;
    cv::inRange(hsv, cv::Scalar(100, 30, 50), cv::Scalar(150, 255, 255), purpleMask);

    // Combine masks
    cv::Mat wellMask = pinkMask | purpleMask;

    // Morphological operations to clean up
    cv::Mat kernel = cv::getStructuringElement(cv::MORPH_ELLIPSE, cv::Size(5, 5));
    cv::morphologyEx(wellMask, wellMask, cv::MORPH_CLOSE, kernel);
    cv::morphologyEx(wellMask, wellMask, cv::MORPH_OPEN, kernel);

    return wellMask;
}

// Find plate region using color segmentation
static bool findPlateByColor(const cv::Mat& bgr, std::vector<cv::Point2f>& corners) {
    cv::Mat wellMask = createWellColorMask(bgr);

    // Dilate to connect nearby wells
    cv::Mat kernel = cv::getStructuringElement(cv::MORPH_ELLIPSE, cv::Size(15, 15));
    cv::dilate(wellMask, wellMask, kernel, cv::Point(-1, -1), 3);

    // Find contours
    std::vector<std::vector<cv::Point>> contours;
    cv::findContours(wellMask, contours, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_SIMPLE);

    if (contours.empty()) return false;

    // Find largest contour
    int largestIdx = 0;
    double maxArea = 0;
    for (size_t i = 0; i < contours.size(); i++) {
        double area = cv::contourArea(contours[i]);
        if (area > maxArea) {
            maxArea = area;
            largestIdx = i;
        }
    }

    // Check if area is reasonable (at least 10% of image)
    double imageArea = bgr.cols * bgr.rows;
    if (maxArea < imageArea * 0.10) return false;

    // Get convex hull
    std::vector<cv::Point> hull;
    cv::convexHull(contours[largestIdx], hull);

    // Fit minimum area rectangle
    cv::RotatedRect minRect = cv::minAreaRect(hull);
    cv::Point2f rectPoints[4];
    minRect.points(rectPoints);

    // Check aspect ratio
    float rectWidth = minRect.size.width;
    float rectHeight = minRect.size.height;
    if (rectWidth < rectHeight) std::swap(rectWidth, rectHeight);
    float aspectRatio = rectWidth / rectHeight;

    if (aspectRatio < 1.0 || aspectRatio > 2.5) return false;

    corners.assign(rectPoints, rectPoints + 4);
    sortCorners(corners);
    return true;
}

// Find plate region using edge detection
static bool findPlateByEdges(const cv::Mat& gray, std::vector<cv::Point2f>& corners, int width, int height) {
    // Multi-scale edge detection
    cv::Mat edges;
    cv::Canny(gray, edges, 30, 100);

    // Dilate edges
    cv::Mat kernel = cv::getStructuringElement(cv::MORPH_RECT, cv::Size(3, 3));
    cv::dilate(edges, edges, kernel, cv::Point(-1, -1), 2);

    // Find contours
    std::vector<std::vector<cv::Point>> contours;
    cv::findContours(edges, contours, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_SIMPLE);

    if (contours.empty()) return false;

    // Sort by area
    std::sort(contours.begin(), contours.end(), [](const std::vector<cv::Point>& a, const std::vector<cv::Point>& b) {
        return cv::contourArea(a) > cv::contourArea(b);
    });

    // Try to find quadrilateral
    for (const auto& contour : contours) {
        double area = cv::contourArea(contour);
        if (area < width * height * 0.10 || area > width * height * 0.98) continue;

        std::vector<cv::Point> approx;
        double epsilon = 0.02 * cv::arcLength(contour, true);
        cv::approxPolyDP(contour, approx, epsilon, true);

        if (approx.size() == 4 && cv::isContourConvex(approx)) {
            cv::Rect bbox = cv::boundingRect(approx);
            double aspectRatio = (double)bbox.width / bbox.height;

            if (aspectRatio > 1.0 && aspectRatio < 2.5) {
                for (const auto& pt : approx) {
                    corners.push_back(cv::Point2f(pt.x, pt.y));
                }
                sortCorners(corners);
                return true;
            }
        }
    }

    // Fallback: use largest contour's bounding rect
    if (!contours.empty()) {
        cv::RotatedRect minRect = cv::minAreaRect(contours[0]);
        cv::Point2f rectPoints[4];
        minRect.points(rectPoints);

        float rectWidth = minRect.size.width;
        float rectHeight = minRect.size.height;
        if (rectWidth < rectHeight) std::swap(rectWidth, rectHeight);
        float aspectRatio = rectWidth / rectHeight;

        if (aspectRatio > 0.8 && aspectRatio < 3.0) {
            corners.assign(rectPoints, rectPoints + 4);
            sortCorners(corners);
            return true;
        }
    }

    return false;
}

// Validate detected circles by checking color consistency
static bool validateCircleByColor(const cv::Mat& bgr, const cv::Vec3f& circle) {
    int cx = (int)circle[0];
    int cy = (int)circle[1];
    int r = (int)(circle[2] * 0.6);  // Sample inner region

    if (cx - r < 0 || cx + r >= bgr.cols || cy - r < 0 || cy + r >= bgr.rows) {
        return false;
    }

    // Sample center region
    cv::Rect roi(cx - r, cy - r, r * 2, r * 2);
    cv::Mat sample = bgr(roi);

    // Convert to HSV
    cv::Mat hsv;
    cv::cvtColor(sample, hsv, cv::COLOR_BGR2HSV);

    // Calculate mean HSV
    cv::Scalar meanHsv = cv::mean(hsv);

    // Check if color is in pink or purple range
    double h = meanHsv[0];
    double s = meanHsv[1];
    double v = meanHsv[2];

    // Pink: H=150-180 or 0-15, S>30, V>80
    bool isPink = ((h >= 150 || h <= 15) && s > 30 && v > 80);

    // Purple: H=100-150, S>30, V>50
    bool isPurple = (h >= 100 && h <= 150 && s > 30 && v > 50);

    return isPink || isPurple;
}

// ============================================================================
// Main Detection Functions
// ============================================================================

__attribute__((visibility("default"))) __attribute__((used))
const char* getOpenCVVersion() {
    return CV_VERSION;
}

// Original single-pass circle detection (kept for compatibility)
__attribute__((visibility("default"))) __attribute__((used))
CircleDetectionResult* detectCircles(
    uint8_t* imageData,
    int width,
    int height,
    int minRadius,
    int maxRadius,
    double dp,
    double minDist,
    double param1,
    double param2
) {
    CircleDetectionResult* result = (CircleDetectionResult*)malloc(sizeof(CircleDetectionResult));
    result->circles = nullptr;
    result->count = 0;
    result->error = 0;

    if (imageData == nullptr || width <= 0 || height <= 0) {
        result->error = 1;
        return result;
    }

    try {
        cv::Mat rgba(height, width, CV_8UC4, imageData);
        cv::Mat gray;
        cv::cvtColor(rgba, gray, cv::COLOR_RGBA2GRAY);

        cv::Mat blurred;
        cv::GaussianBlur(gray, blurred, cv::Size(9, 9), 2, 2);

        std::vector<cv::Vec3f> circles;
        cv::HoughCircles(blurred, circles, cv::HOUGH_GRADIENT,
                         dp, minDist, param1, param2, minRadius, maxRadius);

        if (!circles.empty()) {
            result->count = circles.size();
            result->circles = (Circle*)malloc(sizeof(Circle) * result->count);
            for (int i = 0; i < result->count; i++) {
                result->circles[i].x = circles[i][0];
                result->circles[i].y = circles[i][1];
                result->circles[i].radius = circles[i][2];
            }
        }
    } catch (...) {
        result->error = 2;
    }

    return result;
}

// Enhanced multi-pass circle detection
__attribute__((visibility("default"))) __attribute__((used))
CircleDetectionResult* detectCirclesMultiPass(
    uint8_t* imageData,
    int width,
    int height,
    int minRadius,
    int maxRadius
) {
    CircleDetectionResult* result = (CircleDetectionResult*)malloc(sizeof(CircleDetectionResult));
    result->circles = nullptr;
    result->count = 0;
    result->error = 0;

    if (imageData == nullptr || width <= 0 || height <= 0) {
        result->error = 1;
        return result;
    }

    try {
        cv::Mat rgba(height, width, CV_8UC4, imageData);
        cv::Mat bgr;
        cv::cvtColor(rgba, bgr, cv::COLOR_RGBA2BGR);

        cv::Mat gray;
        cv::cvtColor(bgr, gray, cv::COLOR_BGR2GRAY);

        // Calculate expected parameters
        double expectedCell = std::min((double)width / 12.0, (double)height / 8.0);
        double minDist = expectedCell * 0.65;

        // OPTIMIZED: 3 blur × 3 param2 = 9 calls only
        int blurSizes[] = {7, 9, 11};
        double param2Values[] = {22, 28, 35};

        std::vector<cv::Vec3f> allCircles;

        for (int blurSize : blurSizes) {
            cv::Mat blurred;
            cv::GaussianBlur(gray, blurred, cv::Size(blurSize, blurSize), 2, 2);

            for (double param2 : param2Values) {
                std::vector<cv::Vec3f> circles;
                cv::HoughCircles(blurred, circles, cv::HOUGH_GRADIENT,
                                1.0, minDist, 50, param2, minRadius, maxRadius);

                for (const auto& c : circles) {
                    allCircles.push_back(c);
                }

                // Early exit if enough circles found
                if (allCircles.size() >= 100) break;
            }
            if (allCircles.size() >= 100) break;
        }

        // Remove duplicates
        std::vector<cv::Vec3f> uniqueCircles;
        double mergeThreshold = minDist * 0.4;

        for (const auto& c1 : allCircles) {
            bool isDuplicate = false;
            for (auto& c2 : uniqueCircles) {
                float dx = c1[0] - c2[0];
                float dy = c1[1] - c2[1];
                float dist = sqrt(dx*dx + dy*dy);
                if (dist < mergeThreshold) {
                    // Average the positions
                    c2[0] = (c1[0] + c2[0]) / 2;
                    c2[1] = (c1[1] + c2[1]) / 2;
                    c2[2] = (c1[2] + c2[2]) / 2;
                    isDuplicate = true;
                    break;
                }
            }
            if (!isDuplicate) {
                uniqueCircles.push_back(c1);
            }
        }

        // Filter by median radius
        if (!uniqueCircles.empty()) {
            std::vector<float> radii;
            for (const auto& c : uniqueCircles) {
                radii.push_back(c[2]);
            }
            std::sort(radii.begin(), radii.end());
            float medianRadius = radii[radii.size() / 2];

            std::vector<cv::Vec3f> filtered;
            for (const auto& c : uniqueCircles) {
                if (c[2] >= medianRadius * 0.5 && c[2] <= medianRadius * 1.5) {
                    if (c[0] > medianRadius && c[0] < width - medianRadius &&
                        c[1] > medianRadius && c[1] < height - medianRadius) {
                        filtered.push_back(c);
                    }
                }
            }
            uniqueCircles = filtered;
        }

        // Allocate result
        if (!uniqueCircles.empty()) {
            result->count = uniqueCircles.size();
            result->circles = (Circle*)malloc(sizeof(Circle) * result->count);
            for (size_t i = 0; i < uniqueCircles.size(); i++) {
                result->circles[i].x = uniqueCircles[i][0];
                result->circles[i].y = uniqueCircles[i][1];
                result->circles[i].radius = uniqueCircles[i][2];
            }
        }
    } catch (...) {
        result->error = 2;
    }

    return result;
}

// Plate corner detection
__attribute__((visibility("default"))) __attribute__((used))
PlateCorners* detectPlateCorners(
    uint8_t* imageData,
    int width,
    int height
) {
    PlateCorners* result = (PlateCorners*)malloc(sizeof(PlateCorners));
    result->valid = 0;

    if (imageData == nullptr || width <= 0 || height <= 0) {
        return result;
    }

    try {
        cv::Mat rgba(height, width, CV_8UC4, imageData);
        cv::Mat bgr;
        cv::cvtColor(rgba, bgr, cv::COLOR_RGBA2BGR);

        std::vector<cv::Point2f> corners;

        // Try color-based detection first
        if (!findPlateByColor(bgr, corners)) {
            cv::Mat gray;
            cv::cvtColor(bgr, gray, cv::COLOR_BGR2GRAY);
            cv::Mat filtered;
            cv::bilateralFilter(gray, filtered, 9, 75, 75);

            if (!findPlateByEdges(filtered, corners, width, height)) {
                return result;
            }
        }

        if (corners.size() == 4) {
            result->x1 = corners[0].x; result->y1 = corners[0].y;
            result->x2 = corners[1].x; result->y2 = corners[1].y;
            result->x3 = corners[2].x; result->y3 = corners[2].y;
            result->x4 = corners[3].x; result->y4 = corners[3].y;
            result->valid = 1;
        }
    } catch (...) {
        result->valid = 0;
    }

    return result;
}

// Perspective warp
__attribute__((visibility("default"))) __attribute__((used))
WarpResult* warpPerspective(
    uint8_t* imageData,
    int width,
    int height,
    float srcX1, float srcY1,
    float srcX2, float srcY2,
    float srcX3, float srcY3,
    float srcX4, float srcY4,
    int dstWidth,
    int dstHeight
) {
    WarpResult* result = (WarpResult*)malloc(sizeof(WarpResult));
    result->imageData = nullptr;
    result->width = 0;
    result->height = 0;
    result->error = 0;

    if (imageData == nullptr || width <= 0 || height <= 0) {
        result->error = 1;
        return result;
    }

    try {
        cv::Mat rgba(height, width, CV_8UC4, imageData);

        std::vector<cv::Point2f> srcPoints = {
            cv::Point2f(srcX1, srcY1),
            cv::Point2f(srcX2, srcY2),
            cv::Point2f(srcX3, srcY3),
            cv::Point2f(srcX4, srcY4)
        };

        std::vector<cv::Point2f> dstPoints = {
            cv::Point2f(0, 0),
            cv::Point2f(dstWidth - 1, 0),
            cv::Point2f(dstWidth - 1, dstHeight - 1),
            cv::Point2f(0, dstHeight - 1)
        };

        cv::Mat M = cv::getPerspectiveTransform(srcPoints, dstPoints);
        cv::Mat warped;
        cv::warpPerspective(rgba, warped, M, cv::Size(dstWidth, dstHeight));

        int dataSize = dstWidth * dstHeight * 4;
        result->imageData = (uint8_t*)malloc(dataSize);
        result->width = dstWidth;
        result->height = dstHeight;
        memcpy(result->imageData, warped.data, dataSize);

    } catch (...) {
        result->error = 2;
    }

    return result;
}

// ============================================================================
// ENHANCED ROBUST PIPELINE
// ============================================================================

__attribute__((visibility("default"))) __attribute__((used))
WarpResult* normalizeAndDetectPlate(
    uint8_t* imageData,
    int width,
    int height
) {
    WarpResult* result = (WarpResult*)malloc(sizeof(WarpResult));
    result->imageData = nullptr;
    result->width = 0;
    result->height = 0;
    result->error = 0;

    if (imageData == nullptr || width <= 0 || height <= 0) {
        result->error = 1;
        return result;
    }

    try {
        cv::Mat rgba(height, width, CV_8UC4, imageData);
        cv::Mat bgr;
        cv::cvtColor(rgba, bgr, cv::COLOR_RGBA2BGR);

        // ============================================================
        // STAGE 1: FAST IMAGE ENHANCEMENT
        // ============================================================

        // 1.1 Auto White Balance
        autoWhiteBalance(bgr);

        // 1.2 Auto Gamma Correction
        autoGamma(bgr);

        // 1.3 CLAHE on L channel
        applyCLAHE(bgr, 2.0);

        // 1.4 Fast Gaussian blur instead of slow bilateral
        cv::Mat filtered;
        cv::GaussianBlur(bgr, filtered, cv::Size(5, 5), 1.5);

        // ============================================================
        // STAGE 2: PLATE LOCALIZATION
        // ============================================================

        std::vector<cv::Point2f> plateCorners;
        bool foundPlate = false;

        // Strategy 1: Color-based detection
        foundPlate = findPlateByColor(filtered, plateCorners);

        // Strategy 2: Edge-based detection
        if (!foundPlate) {
            cv::Mat gray;
            cv::cvtColor(filtered, gray, cv::COLOR_BGR2GRAY);
            foundPlate = findPlateByEdges(gray, plateCorners, width, height);
        }

        // Strategy 3: Use full image with margin crop
        if (!foundPlate) {
            int marginX = width * 0.05;
            int marginY = height * 0.05;
            plateCorners = {
                cv::Point2f(marginX, marginY),
                cv::Point2f(width - marginX, marginY),
                cv::Point2f(width - marginX, height - marginY),
                cv::Point2f(marginX, height - marginY)
            };
        }

        // ============================================================
        // STAGE 3: PERSPECTIVE CORRECTION
        // ============================================================

        // Output dimensions - smaller for speed
        int dstWidth = std::min(1200, width);
        int dstHeight = (int)(dstWidth / 1.5);

        std::vector<cv::Point2f> dstPoints = {
            cv::Point2f(0, 0),
            cv::Point2f(dstWidth - 1, 0),
            cv::Point2f(dstWidth - 1, dstHeight - 1),
            cv::Point2f(0, dstHeight - 1)
        };

        cv::Mat M = cv::getPerspectiveTransform(plateCorners, dstPoints);
        cv::Mat warped;
        cv::warpPerspective(filtered, warped, M, cv::Size(dstWidth, dstHeight));

        // Convert to RGBA
        cv::Mat rgbaOut;
        cv::cvtColor(warped, rgbaOut, cv::COLOR_BGR2RGBA);

        // Allocate and copy result
        int dataSize = dstWidth * dstHeight * 4;
        result->imageData = (uint8_t*)malloc(dataSize);
        result->width = dstWidth;
        result->height = dstHeight;
        memcpy(result->imageData, rgbaOut.data, dataSize);

    } catch (...) {
        result->error = 2;
    }

    return result;
}

// ============================================================================
// OPTIMIZED ROBUST DETECTION - Fast but accurate
// ============================================================================

__attribute__((visibility("default"))) __attribute__((used))
CircleDetectionResult* detectWellsRobust(
    uint8_t* imageData,
    int width,
    int height
) {
    CircleDetectionResult* result = (CircleDetectionResult*)malloc(sizeof(CircleDetectionResult));
    result->circles = nullptr;
    result->count = 0;
    result->error = 0;

    if (imageData == nullptr || width <= 0 || height <= 0) {
        result->error = 1;
        return result;
    }

    try {
        cv::Mat rgba(height, width, CV_8UC4, imageData);
        cv::Mat bgr;
        cv::cvtColor(rgba, bgr, cv::COLOR_RGBA2BGR);

        // Apply FAST enhancement pipeline
        autoWhiteBalance(bgr);
        applyCLAHE(bgr, 2.0);

        // Use faster Gaussian blur instead of bilateral
        cv::Mat filtered;
        cv::GaussianBlur(bgr, filtered, cv::Size(5, 5), 1.5);

        cv::Mat gray;
        cv::cvtColor(filtered, gray, cv::COLOR_BGR2GRAY);

        // Calculate expected well parameters
        double expectedCellW = (double)width / 12.0;
        double expectedCellH = (double)height / 8.0;
        double expectedRadius = std::min(expectedCellW, expectedCellH) * 0.35;
        int minR = (int)(expectedRadius * 0.5);
        int maxR = (int)(expectedRadius * 1.5);
        double minDist = std::min(expectedCellW, expectedCellH) * 0.6;

        std::vector<cv::Vec3f> allCircles;

        // OPTIMIZED: Only 3 blur sizes × 3 param2 values = 9 calls (was 60)
        int blurSizes[] = {7, 9, 11};
        double param2Values[] = {20, 28, 38};

        for (int blurSize : blurSizes) {
            cv::Mat blurred;
            cv::GaussianBlur(gray, blurred, cv::Size(blurSize, blurSize), 2, 2);

            for (double param2 : param2Values) {
                std::vector<cv::Vec3f> circles;
                cv::HoughCircles(blurred, circles, cv::HOUGH_GRADIENT,
                                1.0, minDist, 50, param2,
                                minR, maxR);

                for (const auto& c : circles) {
                    allCircles.push_back(c);
                }

                // Early exit if we found enough circles
                if (allCircles.size() >= 100) break;
            }
            if (allCircles.size() >= 100) break;
        }

        // Cluster and merge nearby circles
        std::vector<cv::Vec3f> mergedCircles;
        double clusterThreshold = minDist * 0.4;

        for (const auto& c1 : allCircles) {
            bool merged = false;
            for (auto& c2 : mergedCircles) {
                float dx = c1[0] - c2[0];
                float dy = c1[1] - c2[1];
                float dist = sqrt(dx*dx + dy*dy);
                if (dist < clusterThreshold) {
                    c2[0] = (c1[0] + c2[0]) / 2;
                    c2[1] = (c1[1] + c2[1]) / 2;
                    c2[2] = (c1[2] + c2[2]) / 2;
                    merged = true;
                    break;
                }
            }
            if (!merged) {
                mergedCircles.push_back(c1);
            }
        }

        // Skip color validation if we have enough circles (faster)
        std::vector<cv::Vec3f> validCircles = mergedCircles;

        // Filter by median radius
        if (validCircles.size() > 10) {
            std::vector<float> radii;
            for (const auto& c : validCircles) {
                radii.push_back(c[2]);
            }
            std::sort(radii.begin(), radii.end());
            float medianRadius = radii[radii.size() / 2];

            std::vector<cv::Vec3f> finalFiltered;
            float edgeMargin = medianRadius * 0.3;
            for (const auto& c : validCircles) {
                if (c[2] >= medianRadius * 0.5 && c[2] <= medianRadius * 2.0) {
                    if (c[0] > edgeMargin && c[0] < width - edgeMargin &&
                        c[1] > edgeMargin && c[1] < height - edgeMargin) {
                        finalFiltered.push_back(c);
                    }
                }
            }
            validCircles = finalFiltered;
        }

        // Allocate result
        if (!validCircles.empty()) {
            result->count = validCircles.size();
            result->circles = (Circle*)malloc(sizeof(Circle) * result->count);
            for (size_t i = 0; i < validCircles.size(); i++) {
                result->circles[i].x = validCircles[i][0];
                result->circles[i].y = validCircles[i][1];
                result->circles[i].radius = validCircles[i][2];
            }
        }

    } catch (...) {
        result->error = 2;
    }

    return result;
}

} // extern "C"
