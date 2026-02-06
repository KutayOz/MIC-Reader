#!/usr/bin/env python3
"""
Test BLOB DETECTION (Dart fallback when OpenCV unavailable)
This simulates what happens when NativeOpenCV.isAvailable = false
"""

import cv2
import numpy as np

def simulate_dart_plate_detection(image):
    """Same as before"""
    h, w = image.shape[:2]
    hsv = cv2.cvtColor(image, cv2.COLOR_BGR2HSV)

    well_pixels = []
    for y in range(0, h, 3):
        for x in range(0, w, 3):
            b, g, r = image[y, x].tolist()
            hue, sat, val = hsv[y, x].tolist()

            if val > 250 or val < 50:
                continue

            is_pink = sat > 15 and sat < 100 and r > g * 0.9 and r > b * 0.8 and r > 130
            is_purple = sat > 50 and hue >= 115 and hue <= 178 and val > 60

            if is_pink or is_purple:
                well_pixels.append((x, y))

    if len(well_pixels) >= 100:
        xs = [p[0] for p in well_pixels]
        ys = [p[1] for p in well_pixels]
        min_x, max_x = min(xs), max(xs)
        min_y, max_y = min(ys), max(ys)

        estimated_cell_w = (max_x - min_x) / 12
        estimated_cell_h = (max_y - min_y) / 8
        pad_x = int(estimated_cell_w * 0.3)
        pad_y = int(estimated_cell_h * 0.3)

        min_x = max(0, min_x - pad_x)
        min_y = max(0, min_y - pad_y)
        max_x = min(w - 1, max_x + pad_x)
        max_y = min(h - 1, max_y + pad_y)

        plate = image[min_y:max_y, min_x:max_x].copy()
        ph, pw = plate.shape[:2]

        left = int(pw * 0.02)
        top = int(ph * 0.03)
        right = int(pw * 0.02)
        bottom = int(ph * 0.03)

        plate = plate[top:ph-bottom, left:pw-right]
        return plate

    margin_x = int(w * 0.08)
    margin_y = int(h * 0.10)
    return image[margin_y:h-margin_y, margin_x:w-margin_x].copy()


def rgb_to_hsv(r, g, b):
    """Convert RGB to HSV (H: 0-179, S: 0-255, V: 0-255) like Dart"""
    r_norm = r / 255.0
    g_norm = g / 255.0
    b_norm = b / 255.0

    max_val = max(r_norm, g_norm, b_norm)
    min_val = min(r_norm, g_norm, b_norm)
    delta = max_val - min_val

    v = max_val * 255

    if max_val == 0:
        s = 0
    else:
        s = (delta / max_val) * 255

    if delta == 0:
        h = 0
    elif max_val == r_norm:
        h = 60 * (((g_norm - b_norm) / delta) % 6)
    elif max_val == g_norm:
        h = 60 * (((b_norm - r_norm) / delta) + 2)
    else:
        h = 60 * (((r_norm - g_norm) / delta) + 4)

    if h < 0:
        h += 360
    h = h / 2  # Convert to 0-179

    return h, s, v


def find_well_colored_pixels_dart(plate):
    """
    Simulate Dart's _findWellColoredPixels in grid_fitter.dart
    """
    h, w = plate.shape[:2]
    pixels = []

    margin_x = int(w * 0.03)
    margin_y = int(h * 0.03)

    for y in range(margin_y, h - margin_y, 2):
        for x in range(margin_x, w - margin_x, 2):
            b, g, r = plate[y, x].tolist()

            hue, sat, val = rgb_to_hsv(r, g, b)

            if val > 240 or val < 50:
                continue
            if sat < 25:
                continue

            # Pink check (Dart)
            is_pink = sat > 25 and sat < 120 and r > g * 0.85 and r > b * 0.75 and r > 100

            # Purple check (Dart)
            is_purple = sat > 35 and hue >= 105 and hue <= 178 and val > 45

            if is_pink or is_purple:
                pixels.append((x, y))

    return pixels


def cluster_into_centers_dart(pixels, w, h, expected_sx, expected_sy):
    """
    Simulate Dart's _clusterIntoCenters
    """
    bin_size_x = int(expected_sx * 0.7)
    bin_size_y = int(expected_sy * 0.7)

    if bin_size_x <= 0 or bin_size_y <= 0:
        return []

    bins_x = (w + bin_size_x - 1) // bin_size_x
    bins_y = (h + bin_size_y - 1) // bin_size_y

    bins = {}
    for x, y in pixels:
        bin_x = x // bin_size_x
        bin_y = y // bin_size_y
        key = bin_y * bins_x + bin_x
        if key not in bins:
            bins[key] = []
        bins[key].append((x, y))

    min_pixels = 5
    centers = []

    for points in bins.values():
        if len(points) >= min_pixels:
            sum_x = sum(p[0] for p in points)
            sum_y = sum(p[1] for p in points)
            centers.append((sum_x / len(points), sum_y / len(points)))

    # Merge close centers
    merge_threshold = min(expected_sx, expected_sy) * 0.5
    merged = []
    used = [False] * len(centers)

    for i in range(len(centers)):
        if used[i]:
            continue

        sum_x = centers[i][0]
        sum_y = centers[i][1]
        count = 1
        used[i] = True

        for j in range(i + 1, len(centers)):
            if used[j]:
                continue

            dx = centers[i][0] - centers[j][0]
            dy = centers[i][1] - centers[j][1]
            dist = np.sqrt(dx*dx + dy*dy)

            if dist < merge_threshold:
                sum_x += centers[j][0]
                sum_y += centers[j][1]
                count += 1
                used[j] = True

        merged.append((sum_x / count, sum_y / count))

    return merged


def fit_grid_from_blob_centers(centers, w, h, expected_sx, expected_sy):
    """
    Simulate Dart's _fitGridFromCenters
    """
    # Estimate step from pairs
    step_x = estimate_step_from_pairs_dart(centers, axis=0, expected_step=expected_sx, max_other_dist=expected_sy*0.4)
    step_y = estimate_step_from_pairs_dart(centers, axis=1, expected_step=expected_sy, max_other_dist=expected_sx*0.4)

    if step_x is None:
        step_x = expected_sx
    if step_y is None:
        step_y = expected_sy

    # Validate step ratio
    step_ratio = step_x / step_y
    if step_ratio < 0.85 or step_ratio > 1.15:
        avg_step = (step_x + step_y) / 2
        step_x = avg_step
        step_y = avg_step

    # Find best origin
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
            score = score_grid_dart(centers, ox, oy, step_x, step_y)
            if score > best_score:
                best_score = score
                best_ox, best_oy = ox, oy

    # Refine with LSQ
    ox, oy, sx, sy = refine_grid_lsq_dart(centers, best_ox, best_oy, step_x, step_y)

    return ox, oy, sx, sy


def estimate_step_from_pairs_dart(centers, axis, expected_step, max_other_dist):
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


def score_grid_dart(centers, ox, oy, sx, sy):
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


def refine_grid_lsq_dart(centers, ox, oy, sx, sy):
    threshold = max(sx, sy) * 0.35

    for iteration in range(3):
        rows_l, cols_l, cxs, cys = [], [], [], []

        for cx, cy in centers:
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


def main():
    image_path = "/Users/kutinyo/Desktop/Sample/test_images/WhatsApp Image 2026-02-05 at 14.15.10.jpeg"
    output_path = "/Users/kutinyo/Desktop/Sample/files/debug_blob_detection.png"

    image = cv2.imread(image_path)
    if image is None:
        print(f"Error loading {image_path}")
        return

    print("=" * 60)
    print("SIMULATING DART BLOB DETECTION (OpenCV fallback)")
    print("=" * 60)

    # Step 1: Plate detection
    print("\n[1] Plate Detection")
    plate = simulate_dart_plate_detection(image)
    h, w = plate.shape[:2]
    print(f"    Plate size: {w}x{h}")

    # Step 2: Find well-colored pixels
    print("\n[2] Find Well-Colored Pixels")
    well_pixels = find_well_colored_pixels_dart(plate)
    print(f"    Found {len(well_pixels)} well-colored pixels")

    if len(well_pixels) < 50:
        print("    ERROR: Not enough colored pixels!")
        return

    # Step 3: Cluster into centers
    print("\n[3] Cluster into Centers")
    expected_sx = w / 12
    expected_sy = h / 8
    centers = cluster_into_centers_dart(well_pixels, w, h, expected_sx, expected_sy)
    print(f"    Found {len(centers)} cluster centers")

    if len(centers) < 20:
        print("    ERROR: Not enough cluster centers!")
        return

    # Step 4: Fit grid
    print("\n[4] Grid Fitting")
    ox, oy, sx, sy = fit_grid_from_blob_centers(centers, w, h, expected_sx, expected_sy)
    print(f"    Grid: origin=({ox:.1f}, {oy:.1f}), step=({sx:.1f}, {sy:.1f})")

    # Step 5: Visualize
    print("\n[5] Generating Debug Image")
    debug = plate.copy()

    # Draw blob centers (yellow)
    for cx, cy in centers:
        cv2.circle(debug, (int(cx), int(cy)), 8, (0, 255, 255), 2)
        cv2.circle(debug, (int(cx), int(cy)), 3, (0, 0, 255), -1)

    # Draw fitted grid (blue/cyan)
    matched_count = 0
    for row in range(8):
        for col in range(12):
            grid_cx = int(ox + col * sx)
            grid_cy = int(oy + row * sy)
            grid_r = int(min(sx, sy) * 0.42)

            matched = False
            for cx, cy in centers:
                dx = cx - grid_cx
                dy = cy - grid_cy
                if np.sqrt(dx*dx + dy*dy) < sx * 0.3:
                    matched = True
                    matched_count += 1
                    break

            color = (255, 0, 0) if matched else (255, 255, 0)
            cv2.circle(debug, (grid_cx, grid_cy), grid_r, color, 1)

            label = f"{chr(65+row)}{col+1}"
            cv2.putText(debug, label, (grid_cx-10, grid_cy-grid_r-2),
                       cv2.FONT_HERSHEY_SIMPLEX, 0.25, color, 1)

    cv2.imwrite(output_path, debug)
    print(f"    Saved to: {output_path}")
    print(f"\n    Grid matching: {matched_count}/96 wells matched to blob centers")
    print(f"    (Yellow = blob centers, Blue = grid matched, Cyan = grid not matched)")


if __name__ == "__main__":
    main()
