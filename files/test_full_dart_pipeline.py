#!/usr/bin/env python3
"""
Simulate the FULL Dart pipeline to debug grid fitting issues:
1. Load image
2. Plate detection (simulate Dart's approach)
3. Circle detection with OpenCV
4. Grid fitting
5. Generate debug output
"""

import cv2
import numpy as np

def simulate_dart_plate_detection(image):
    """
    Simulate Dart's _findPlateBoundsByColor and _cropToWellArea
    """
    h, w = image.shape[:2]
    hsv = cv2.cvtColor(image, cv2.COLOR_BGR2HSV)

    print(f"\n[1] Plate Detection")
    print(f"    Original image: {w}x{h}")

    # Find well-colored pixels (simulate Dart's _findPlateBoundsByColor)
    well_pixels = []

    for y in range(0, h, 3):
        for x in range(0, w, 3):
            b, g, r = image[y, x].tolist()
            hue, sat, val = hsv[y, x].tolist()

            if val > 250 or val < 50:
                continue

            # Pink detection (Dart criteria)
            is_pink = sat > 15 and sat < 100 and r > g * 0.9 and r > b * 0.8 and r > 130

            # Purple detection (Dart criteria)
            is_purple = sat > 50 and hue >= 115 and hue <= 178 and val > 60

            if is_pink or is_purple:
                well_pixels.append((x, y))

    print(f"    Well-colored pixels found: {len(well_pixels)}")

    if len(well_pixels) >= 100:
        xs = [p[0] for p in well_pixels]
        ys = [p[1] for p in well_pixels]
        min_x, max_x = min(xs), max(xs)
        min_y, max_y = min(ys), max(ys)

        # Add padding
        estimated_cell_w = (max_x - min_x) / 12
        estimated_cell_h = (max_y - min_y) / 8
        pad_x = int(estimated_cell_w * 0.3)
        pad_y = int(estimated_cell_h * 0.3)

        min_x = max(0, min_x - pad_x)
        min_y = max(0, min_y - pad_y)
        max_x = min(w - 1, max_x + pad_x)
        max_y = min(h - 1, max_y + pad_y)

        crop_w = max_x - min_x
        crop_h = max_y - min_y

        print(f"    Color-based crop: ({min_x},{min_y}) size {crop_w}x{crop_h}")

        # Crop with light margins (Dart's _cropToWellAreaLight)
        plate = image[min_y:max_y, min_x:max_x].copy()
        ph, pw = plate.shape[:2]

        # Light margins
        left = int(pw * 0.02)
        top = int(ph * 0.03)
        right = int(pw * 0.02)
        bottom = int(ph * 0.03)

        plate = plate[top:ph-bottom, left:pw-right]
        print(f"    After light crop: {plate.shape[1]}x{plate.shape[0]}")

        return plate

    # Fallback: center crop with margins
    print("    Fallback: center crop")
    margin_x = int(w * 0.08)
    margin_y = int(h * 0.10)
    return image[margin_y:h-margin_y, margin_x:w-margin_x].copy()


def detect_circles_like_dart(plate):
    """
    Circle detection matching native_opencv.cpp
    """
    h, w = plate.shape[:2]

    print(f"\n[2] Circle Detection")
    print(f"    Plate size: {w}x{h}")

    gray = cv2.cvtColor(plate, cv2.COLOR_BGR2GRAY)

    # Parameters matching native_opencv.cpp
    expected_cell = min(w / 12.0, h / 8.0)
    expected_r = expected_cell * 0.42
    min_r = int(expected_r * 0.5)
    max_r = int(expected_r * 1.3)
    min_dist = expected_cell * 0.65

    print(f"    Expected cell: {expected_cell:.1f}")
    print(f"    Radius range: {min_r} - {max_r}")
    print(f"    Min dist: {min_dist:.1f}")

    dp = 1.0
    param1 = 50
    blur_sizes = [7, 9, 11]
    param2_values = [22, 28, 35]

    all_circles = []

    for blur_size in blur_sizes:
        blurred = cv2.GaussianBlur(gray, (blur_size, blur_size), 2)
        for param2 in param2_values:
            circles = cv2.HoughCircles(
                blurred, cv2.HOUGH_GRADIENT,
                dp=dp, minDist=min_dist, param1=param1, param2=param2,
                minRadius=min_r, maxRadius=max_r
            )
            if circles is not None:
                all_circles.append(circles[0])

    if not all_circles:
        print("    No circles detected!")
        return np.array([]).reshape(0, 3)

    combined = np.vstack(all_circles)
    print(f"    Raw circles: {len(combined)}")

    # Deduplicate
    merge_threshold = min_dist * 0.5
    deduped = _deduplicate(combined, merge_threshold)
    print(f"    After dedup: {len(deduped)}")

    # Filter by radius
    radii = deduped[:, 2]
    med_r = np.median(radii)
    radius_mask = (radii >= med_r * 0.6) & (radii <= med_r * 1.4)
    filtered = deduped[radius_mask]
    print(f"    After radius filter: {len(filtered)}")

    # Filter edge circles
    edge_margin = med_r * 0.5
    edge_mask = ((filtered[:, 0] > edge_margin) &
                 (filtered[:, 0] < w - edge_margin) &
                 (filtered[:, 1] > edge_margin) &
                 (filtered[:, 1] < h - edge_margin))
    final = filtered[edge_mask]
    print(f"    After edge filter: {len(final)}")

    return final


def fit_grid_like_dart(circles, w, h):
    """
    Grid fitting matching Dart's grid_fitter.dart
    """
    print(f"\n[3] Grid Fitting")

    if len(circles) < 20:
        print("    Not enough circles for grid fitting, using naive grid")
        step_x = w / 12
        step_y = h / 8
        return step_x / 2, step_y / 2, step_x, step_y

    centers = circles[:, :2]
    expected_sx = w / 12
    expected_sy = h / 8

    # Estimate step from pairs
    step_x = estimate_step_from_pairs(centers, axis=0, expected_step=expected_sx, max_other_dist=expected_sy*0.4)
    step_y = estimate_step_from_pairs(centers, axis=1, expected_step=expected_sy, max_other_dist=expected_sx*0.4)

    if step_x is None:
        step_x = expected_sx
    if step_y is None:
        step_y = expected_sy

    print(f"    Estimated step: ({step_x:.1f}, {step_y:.1f})")

    # Find best origin (matching Dart's looser bounds)
    candidates_ox = set()
    candidates_oy = set()

    min_ox = -step_x * 0.3
    max_ox = step_x * 1.5
    min_oy = -step_y * 0.3
    max_oy = step_y * 1.5

    for cx, cy in centers:
        for col_guess in range(12):
            ox = cx - col_guess * step_x
            if min_ox < ox < max_ox:
                candidates_ox.add(round(ox, 1))
        for row_guess in range(8):
            oy = cy - row_guess * step_y
            if min_oy < oy < max_oy:
                candidates_oy.add(round(oy, 1))

    candidates_ox.add(round(step_x / 2, 1))
    candidates_oy.add(round(step_y / 2, 1))

    best_ox, best_oy, best_score = step_x / 2, step_y / 2, -1

    for ox in candidates_ox:
        for oy in candidates_oy:
            score = score_grid(centers, ox, oy, step_x, step_y)
            if score > best_score:
                best_score = score
                best_ox, best_oy = ox, oy

    print(f"    Best origin (before LSQ): ({best_ox:.1f}, {best_oy:.1f}) score={best_score}")

    # Refine with LSQ
    ox, oy, sx, sy = refine_grid_lsq(circles, best_ox, best_oy, step_x, step_y)

    print(f"    Final grid: origin=({ox:.1f}, {oy:.1f}), step=({sx:.1f}, {sy:.1f})")

    return ox, oy, sx, sy


def estimate_step_from_pairs(centers, axis, expected_step, max_other_dist):
    n = len(centers)
    unit_dists = []

    for i in range(n):
        for j in range(i+1, n):
            c1, c2 = centers[i], centers[j]
            other_diff = abs(c1[1-axis] - c2[1-axis])
            if other_diff > max_other_dist:
                continue

            axis_diff = abs(c1[axis] - c2[axis])
            if axis_diff < expected_step * 0.5:
                continue

            n_steps = round(axis_diff / expected_step)
            if n_steps < 1 or n_steps > 12:
                continue

            unit_dist = axis_diff / n_steps
            if 0.7 * expected_step < unit_dist < 1.3 * expected_step:
                unit_dists.append(unit_dist)

    if len(unit_dists) < 5:
        return None

    return float(np.median(unit_dists))


def score_grid(centers, ox, oy, sx, sy):
    score = 0
    used_slots = set()
    threshold = max(sx, sy) * 0.35

    for cx, cy in centers:
        col = round((cx - ox) / sx)
        row = round((cy - oy) / sy)

        if 0 <= row < 8 and 0 <= col < 12:
            pred_x = ox + col * sx
            pred_y = oy + row * sy
            err = np.sqrt((cx - pred_x)**2 + (cy - pred_y)**2)

            slot = (int(row), int(col))
            if err < threshold and slot not in used_slots:
                score += 1
                used_slots.add(slot)

    return score


def refine_grid_lsq(circles, ox, oy, sx, sy):
    threshold = max(sx, sy) * 0.35

    for iteration in range(3):
        rows_l, cols_l, cxs, cys = [], [], [], []

        for c in circles:
            cx, cy = c[0], c[1]
            col = round((cx - ox) / sx)
            row = round((cy - oy) / sy)

            if 0 <= row < 8 and 0 <= col < 12:
                pred_x = ox + col * sx
                pred_y = oy + row * sy
                err = np.sqrt((cx - pred_x)**2 + (cy - pred_y)**2)

                if err < threshold:
                    rows_l.append(row)
                    cols_l.append(col)
                    cxs.append(cx)
                    cys.append(cy)

        if len(cxs) < 20:
            break

        cols_arr = np.array(cols_l, dtype=float)
        rows_arr = np.array(rows_l, dtype=float)

        A_x = np.column_stack([np.ones_like(cols_arr), cols_arr])
        ox, sx = np.linalg.lstsq(A_x, np.array(cxs), rcond=None)[0]

        A_y = np.column_stack([np.ones_like(rows_arr), rows_arr])
        oy, sy = np.linalg.lstsq(A_y, np.array(cys), rcond=None)[0]

    return float(ox), float(oy), float(sx), float(sy)


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


def main():
    image_path = "/Users/kutinyo/Desktop/Sample/test_images/WhatsApp Image 2026-02-05 at 14.15.10.jpeg"
    output_path = "/Users/kutinyo/Desktop/Sample/files/debug_full_dart_pipeline.png"

    # Load image
    image = cv2.imread(image_path)
    if image is None:
        print(f"Error loading {image_path}")
        return

    print("=" * 60)
    print("SIMULATING FULL DART PIPELINE")
    print("=" * 60)

    # Step 1: Plate detection
    plate = simulate_dart_plate_detection(image)
    h, w = plate.shape[:2]

    # Step 2: Circle detection
    circles = detect_circles_like_dart(plate)

    # Step 3: Grid fitting
    ox, oy, sx, sy = fit_grid_like_dart(circles, w, h)

    # Step 4: Visualize
    print(f"\n[4] Generating Debug Image")

    debug = plate.copy()

    # Draw detected circles (green)
    for c in circles:
        cx, cy, r = int(c[0]), int(c[1]), int(c[2])
        cv2.circle(debug, (cx, cy), r, (0, 255, 0), 2)
        cv2.circle(debug, (cx, cy), 3, (0, 0, 255), -1)  # Red center

    # Draw fitted grid positions (blue circles, cyan for unmatched)
    for row in range(8):
        for col in range(12):
            grid_cx = int(ox + col * sx)
            grid_cy = int(oy + row * sy)
            grid_r = int(min(sx, sy) * 0.42)

            # Check if there's a detected circle near this position
            matched = False
            for c in circles:
                dx = c[0] - grid_cx
                dy = c[1] - grid_cy
                if np.sqrt(dx*dx + dy*dy) < sx * 0.3:
                    matched = True
                    break

            color = (255, 0, 0) if matched else (255, 255, 0)  # Blue if matched, cyan if not
            cv2.circle(debug, (grid_cx, grid_cy), grid_r, color, 1)

            # Label
            label = f"{chr(65+row)}{col+1}"
            cv2.putText(debug, label, (grid_cx-10, grid_cy-grid_r-2),
                       cv2.FONT_HERSHEY_SIMPLEX, 0.25, color, 1)

    cv2.imwrite(output_path, debug)
    print(f"    Saved to: {output_path}")

    # Count matched/unmatched
    matched_count = 0
    threshold = sx * 0.3
    for row in range(8):
        for col in range(12):
            grid_cx = ox + col * sx
            grid_cy = oy + row * sy
            for c in circles:
                dx = c[0] - grid_cx
                dy = c[1] - grid_cy
                if np.sqrt(dx*dx + dy*dy) < threshold:
                    matched_count += 1
                    break

    print(f"\n    Grid matching: {matched_count}/96 wells matched to detected circles")
    print(f"    (Green = detected circles, Blue = grid positions matching, Cyan = grid not matching)")


if __name__ == "__main__":
    main()
