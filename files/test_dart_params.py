#!/usr/bin/env python3
"""
Test script to simulate Dart/C++ OpenCV parameters on the test image.
This helps debug why the mobile app might not be detecting wells correctly.
"""

import cv2
import numpy as np
import sys

def detect_circles_dart_params(image_path, output_path):
    """Detect circles using the EXACT same parameters as native_opencv.cpp"""

    # Load image
    img = cv2.imread(image_path)
    if img is None:
        print(f"Error: Could not load image {image_path}")
        return

    h, w = img.shape[:2]
    print(f"Image size: {w}x{h}")

    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

    # Parameters EXACTLY matching native_opencv.cpp (after our fixes)
    expected_cell = min(w / 12.0, h / 8.0)
    expected_r = expected_cell * 0.42
    min_r = int(expected_r * 0.5)  # Updated to match Python
    max_r = int(expected_r * 1.3)
    min_dist = expected_cell * 0.65  # Updated to match Python

    print(f"Expected cell: {expected_cell:.1f}")
    print(f"Expected radius: {expected_r:.1f}")
    print(f"Min radius: {min_r}, Max radius: {max_r}")
    print(f"Min dist: {min_dist:.1f}")

    # Parameters from updated native_opencv.cpp
    dp = 1.0  # Updated from 1.2
    param1 = 50  # Updated from 100
    blur_sizes = [7, 9, 11]
    param2_values = [22, 28, 35]

    all_circles = []

    for blur_size in blur_sizes:
        blurred = cv2.GaussianBlur(gray, (blur_size, blur_size), 2)

        for param2 in param2_values:
            circles = cv2.HoughCircles(
                blurred,
                cv2.HOUGH_GRADIENT,
                dp=dp,
                minDist=min_dist,
                param1=param1,
                param2=param2,
                minRadius=min_r,
                maxRadius=max_r
            )

            if circles is not None:
                print(f"  blur={blur_size}, param2={param2}: {len(circles[0])} circles")
                all_circles.append(circles[0])

    if not all_circles:
        print("No circles detected!")
        return

    combined = np.vstack(all_circles)
    print(f"Total before dedup: {len(combined)}")

    # Deduplicate (merge threshold = min_dist * 0.5)
    merge_threshold = min_dist * 0.5
    deduped = _deduplicate(combined, merge_threshold)
    print(f"After dedup: {len(deduped)}")

    # Filter by radius (0.6 - 1.4 × median)
    radii = deduped[:, 2]
    med_r = np.median(radii)
    radius_mask = (radii >= med_r * 0.6) & (radii <= med_r * 1.4)
    filtered = deduped[radius_mask]
    print(f"After radius filter: {len(filtered)}")

    # Filter edge circles (edge_margin = med_r * 0.5)
    edge_margin = med_r * 0.5
    edge_mask = ((filtered[:, 0] > edge_margin) &
                 (filtered[:, 0] < w - edge_margin) &
                 (filtered[:, 1] > edge_margin) &
                 (filtered[:, 1] < h - edge_margin))
    final = filtered[edge_mask]
    print(f"After edge filter: {len(final)}")

    # Draw debug image
    debug = img.copy()
    for c in final:
        cx, cy, r = int(c[0]), int(c[1]), int(c[2])
        cv2.circle(debug, (cx, cy), r, (0, 255, 0), 2)
        cv2.circle(debug, (cx, cy), 3, (0, 0, 255), -1)

    # Add grid overlay to show expected positions
    step_x = w / 12.0
    step_y = h / 8.0

    for row in range(8):
        for col in range(12):
            expected_cx = int(step_x * (col + 0.5))
            expected_cy = int(step_y * (row + 0.5))
            cv2.circle(debug, (expected_cx, expected_cy), 5, (255, 0, 0), 1)  # Blue = expected

    cv2.imwrite(output_path, debug)
    print(f"\nDebug image saved to: {output_path}")
    print(f"Green = detected circles, Blue dots = expected grid positions")


def _deduplicate(circles, merge_dist):
    if len(circles) == 0:
        return circles
    used = np.zeros(len(circles), dtype=bool)
    merged = []
    for i in range(len(circles)):
        if used[i]:
            continue
        cluster = [circles[i]]
        used[i] = True
        for j in range(i + 1, len(circles)):
            if used[j]:
                continue
            dist = np.sqrt((circles[i][0]-circles[j][0])**2 + (circles[i][1]-circles[j][1])**2)
            if dist < merge_dist:
                cluster.append(circles[j])
                used[j] = True
        merged.append(np.mean(cluster, axis=0))
    return np.array(merged)


if __name__ == "__main__":
    image_path = "/Users/kutinyo/Desktop/Sample/test_images/WhatsApp Image 2026-02-05 at 14.15.10.jpeg"
    output_path = "/Users/kutinyo/Desktop/Sample/files/debug_dart_params.png"
    detect_circles_dart_params(image_path, output_path)
