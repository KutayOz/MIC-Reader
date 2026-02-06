"""
Well Extractor v4 - Hough Circle detection with robust grid fitting.

Improvements over v3:
  - Edge circle filtering (remove circles near image boundaries)
  - Better grid step estimation using pairwise same-row/same-col distances
  - RANSAC-style grid refinement: iteratively remove outlier assignments
  - Debug visualization
"""

import cv2
import numpy as np
from config import (
    ROWS, COLS, WELL_MASK_RADIUS_FRACTION,
    SPECULAR_V_THRESHOLD, MIN_SATURATION
)


def extract_wells(plate_image: np.ndarray) -> dict:
    h, w = plate_image.shape[:2]
    
    circles, med_radius = detect_circles(plate_image)
    print(f"       {len(circles)} daire tespit edildi (medyan R={med_radius:.0f})")
    
    if len(circles) < 20:
        print("       [WARN] Yetersiz daire, naif grid kullanılacak")
        grid, grid_params = _naive_grid(w, h, med_radius)
    else:
        grid, grid_params = fit_grid_robust(circles, w, h, med_radius)
    
    origin_x, origin_y, step_x, step_y = grid_params
    print(f"       Grid: başlangıç=({origin_x:.1f}, {origin_y:.1f}), "
          f"adım=({step_x:.1f}, {step_y:.1f})")
    
    matched = sum(1 for v in grid.values() if v['detected'])
    print(f"       {matched}/96 kuyucuk Hough ile eşleşti, {96-matched} interpolasyonla dolduruldu")
    
    # Debug image
    debug = plate_image.copy()
    for (row, col), gdata in grid.items():
        cx, cy = int(gdata['cx']), int(gdata['cy'])
        r = int(gdata.get('radius', med_radius))
        color = (0, 255, 0) if gdata['detected'] else (0, 165, 255)
        cv2.circle(debug, (cx, cy), r, color, 2)
        cv2.circle(debug, (cx, cy), 3, (0, 0, 255), -1)
        label = f"{row},{col}"
        cv2.putText(debug, label, (cx-12, cy-r-4), cv2.FONT_HERSHEY_SIMPLEX, 0.3, color, 1)
    cv2.imwrite('/home/claude/mic_output/debug_grid_v4.png', debug)
    
    # Extract colors
    hsv_image = cv2.cvtColor(plate_image, cv2.COLOR_BGR2HSV)
    wells = {}
    
    for (row, col), gdata in grid.items():
        cx, cy = int(gdata['cx']), int(gdata['cy'])
        r = int(gdata.get('radius', med_radius))
        sample_r = int(r * WELL_MASK_RADIUS_FRACTION)
        
        y1, y2 = max(0, cy - r), min(h, cy + r)
        x1, x2 = max(0, cx - r), min(w, cx + r)
        
        cell_bgr = plate_image[y1:y2, x1:x2]
        cell_hsv = hsv_image[y1:y2, x1:x2]
        
        ch, cw = cell_bgr.shape[:2]
        if ch < 5 or cw < 5:
            wells[(row, col)] = _empty_well(cx, cy, cell_bgr)
            continue
        
        local_cx, local_cy = cx - x1, cy - y1
        
        mask = np.zeros((ch, cw), dtype=np.uint8)
        cv2.circle(mask, (local_cx, local_cy), sample_r, 255, -1)
        
        combined_mask = ((mask > 0) & 
                         (cell_hsv[:, :, 2] < SPECULAR_V_THRESHOLD) &
                         (cell_hsv[:, :, 1] > MIN_SATURATION))
        
        valid_hsv = cell_hsv[combined_mask]
        valid_bgr = cell_bgr[combined_mask]
        
        if len(valid_hsv) < 10:
            valid_hsv = cell_hsv[mask > 0]
            valid_bgr = cell_bgr[mask > 0]
        
        if len(valid_hsv) > 0:
            wells[(row, col)] = {
                'hsv_median': (circular_median_hue(valid_hsv[:, 0]),
                               float(np.median(valid_hsv[:, 1])),
                               float(np.median(valid_hsv[:, 2]))),
                'hsv_mean': (circular_mean_hue(valid_hsv[:, 0]),
                             float(np.mean(valid_hsv[:, 1])),
                             float(np.mean(valid_hsv[:, 2]))),
                'rgb_mean': (float(np.mean(valid_bgr[:, 2])),
                             float(np.mean(valid_bgr[:, 1])),
                             float(np.mean(valid_bgr[:, 0]))),
                'pixel_count': len(valid_hsv),
                'center': (cx, cy),
                'cell_bounds': (x1, y1, x2, y2),
                'radius': r,
                'detected': gdata['detected'],
                'crop': cell_bgr.copy(),
            }
        else:
            wells[(row, col)] = _empty_well(cx, cy, cell_bgr)
    
    return wells


# =====================================================================
# Circle Detection
# =====================================================================

def detect_circles(plate_image: np.ndarray) -> tuple:
    h, w = plate_image.shape[:2]
    gray = cv2.cvtColor(plate_image, cv2.COLOR_BGR2GRAY)
    
    expected_cell = min(w / 12, h / 8)
    expected_r = expected_cell * 0.42
    min_r = int(expected_r * 0.5)
    max_r = int(expected_r * 1.3)
    min_dist = int(expected_cell * 0.65)
    
    all_circles = []
    for blur_size in [7, 9, 11]:
        blurred = cv2.GaussianBlur(gray, (blur_size, blur_size), 2)
        for param2 in [22, 28, 35]:
            circles = cv2.HoughCircles(
                blurred, cv2.HOUGH_GRADIENT, dp=1.0,
                minDist=min_dist, param1=50, param2=param2,
                minRadius=min_r, maxRadius=max_r
            )
            if circles is not None:
                all_circles.append(circles[0])
    
    if not all_circles:
        return np.array([]).reshape(0, 3), expected_r
    
    combined = np.vstack(all_circles)
    deduped = _deduplicate(combined, min_dist * 0.5)
    
    # Filter by radius
    radii = deduped[:, 2]
    med_r = np.median(radii)
    rmask = (radii >= med_r * 0.6) & (radii <= med_r * 1.4)
    filtered = deduped[rmask]
    
    # Filter edge circles: remove circles whose center is within 0.5*radius of image edge
    edge_margin = med_r * 0.5
    edge_mask = ((filtered[:, 0] > edge_margin) &
                 (filtered[:, 0] < w - edge_margin) &
                 (filtered[:, 1] > edge_margin) &
                 (filtered[:, 1] < h - edge_margin))
    filtered = filtered[edge_mask]
    
    return filtered, float(med_r)


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
            if np.sqrt((circles[i][0]-circles[j][0])**2 + (circles[i][1]-circles[j][1])**2) < merge_dist:
                cluster.append(circles[j])
                used[j] = True
        merged.append(np.mean(cluster, axis=0))
    return np.array(merged)


# =====================================================================
# Grid Fitting
# =====================================================================

def fit_grid_robust(circles: np.ndarray, img_w: int, img_h: int,
                    med_radius: float) -> tuple:
    """
    Robust grid fitting:
    1. Cluster X/Y coordinates
    2. Fit linear grid
    3. Assign circles to grid
    4. Iteratively refine by removing outlier assignments
    """
    centers = circles[:, :2].astype(float)
    expected_sx = img_w / 12
    expected_sy = img_h / 8
    
    # --- Step 1: Estimate step size from pairwise distances ---
    # For each pair of circles that are roughly in the same row (similar Y),
    # their X distance should be a multiple of step_x
    step_x = _estimate_step_from_pairs(centers, axis=0, other_axis=1,
                                        expected_step=expected_sx, max_other_dist=expected_sy*0.4)
    step_y = _estimate_step_from_pairs(centers, axis=1, other_axis=0,
                                        expected_step=expected_sy, max_other_dist=expected_sx*0.4)
    
    if step_x is None:
        step_x = expected_sx
    if step_y is None:
        step_y = expected_sy
    
    # --- Step 2: Find origin using brute-force search ---
    best_ox, best_oy, best_score = None, None, -1
    
    # Try origins based on detected circle positions modulo step
    candidate_ox = set()
    candidate_oy = set()
    
    for cx, cy in centers:
        for col_guess in range(COLS):
            ox = cx - col_guess * step_x
            if -step_x * 0.3 < ox < step_x * 1.5:
                candidate_ox.add(round(ox, 1))
        for row_guess in range(ROWS):
            oy = cy - row_guess * step_y
            if -step_y * 0.3 < oy < step_y * 1.5:
                candidate_oy.add(round(oy, 1))
    
    # Also add expected origin
    candidate_ox.add(round(expected_sx / 2, 1))
    candidate_oy.add(round(expected_sy / 2, 1))
    
    for ox in candidate_ox:
        for oy in candidate_oy:
            score, _ = _score_grid(centers, ox, oy, step_x, step_y)
            if score > best_score:
                best_score = score
                best_ox, best_oy = ox, oy
    
    # --- Step 3: Refine grid parameters with least-squares ---
    ox, oy, sx, sy = _refine_grid_lsq(circles, best_ox, best_oy, step_x, step_y)
    
    # --- Step 4: Final assignment ---
    assignments = _assign_circles(circles, ox, oy, sx, sy)
    
    # Build grid
    grid = {}
    for row in range(ROWS):
        for col in range(COLS):
            key = (row, col)
            if key in assignments:
                cx, cy, r = assignments[key]
                grid[key] = {'cx': cx, 'cy': cy, 'radius': r, 'detected': True}
            else:
                grid[key] = {
                    'cx': ox + col * sx,
                    'cy': oy + row * sy,
                    'radius': med_radius,
                    'detected': False
                }
    
    return grid, (ox, oy, sx, sy)


def _estimate_step_from_pairs(centers, axis, other_axis, expected_step, max_other_dist):
    """
    Estimate grid step by looking at distances between circles that share
    roughly the same row (for X step) or column (for Y step).
    """
    n = len(centers)
    unit_dists = []
    
    for i in range(n):
        for j in range(i+1, n):
            # Check if they're in the same row/column (small diff on other axis)
            other_diff = abs(centers[i][other_axis] - centers[j][other_axis])
            if other_diff > max_other_dist:
                continue
            
            axis_diff = abs(centers[i][axis] - centers[j][axis])
            if axis_diff < expected_step * 0.5:
                continue
            
            # How many steps apart?
            n_steps = round(axis_diff / expected_step)
            if n_steps < 1 or n_steps > 12:
                continue
            
            unit_dist = axis_diff / n_steps
            if 0.7 * expected_step < unit_dist < 1.3 * expected_step:
                unit_dists.append(unit_dist)
    
    if len(unit_dists) < 5:
        return None
    
    return float(np.median(unit_dists))


def _score_grid(centers, ox, oy, sx, sy):
    """Score how well circles match a grid with given parameters."""
    score = 0
    used_slots = set()
    threshold = max(sx, sy) * 0.35
    
    for cx, cy in centers:
        col = round((cx - ox) / sx)
        row = round((cy - oy) / sy)
        
        if 0 <= row < ROWS and 0 <= col < COLS:
            pred_x = ox + col * sx
            pred_y = oy + row * sy
            err = np.sqrt((cx - pred_x)**2 + (cy - pred_y)**2)
            
            if err < threshold and (row, col) not in used_slots:
                score += 1
                used_slots.add((row, col))
    
    return score, used_slots


def _refine_grid_lsq(circles, ox, oy, sx, sy):
    """Refine grid parameters using least-squares on good assignments."""
    threshold = max(sx, sy) * 0.35
    
    for iteration in range(3):  # iterative refinement
        rows_l, cols_l, cxs, cys = [], [], [], []
        
        for c in circles:
            cx, cy = c[0], c[1]
            col = round((cx - ox) / sx)
            row = round((cy - oy) / sy)
            
            if 0 <= row < ROWS and 0 <= col < COLS:
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


def _assign_circles(circles, ox, oy, sx, sy):
    """Assign circles to grid positions, keeping best match per slot."""
    threshold = max(sx, sy) * 0.45
    assignments = {}
    
    for c in circles:
        cx, cy, r = c
        col = round((cx - ox) / sx)
        row = round((cy - oy) / sy)
        
        if 0 <= row < ROWS and 0 <= col < COLS:
            pred_x = ox + col * sx
            pred_y = oy + row * sy
            err = np.sqrt((cx - pred_x)**2 + (cy - pred_y)**2)
            
            if err < threshold:
                key = (int(row), int(col))
                if key not in assignments:
                    assignments[key] = (float(cx), float(cy), float(r))
                else:
                    # Keep the one closer to predicted position
                    old_cx, old_cy, _ = assignments[key]
                    old_err = np.sqrt((old_cx - pred_x)**2 + (old_cy - pred_y)**2)
                    if err < old_err:
                        assignments[key] = (float(cx), float(cy), float(r))
    
    return assignments


# =====================================================================
# Utilities
# =====================================================================

def _naive_grid(img_w, img_h, med_radius):
    sx, sy = img_w / COLS, img_h / ROWS
    ox, oy = sx / 2, sy / 2
    grid = {}
    for r in range(ROWS):
        for c in range(COLS):
            grid[(r, c)] = {'cx': ox+c*sx, 'cy': oy+r*sy, 'radius': med_radius, 'detected': False}
    return grid, (ox, oy, sx, sy)


def _empty_well(cx, cy, crop):
    return {
        'hsv_median': (0, 0, 0), 'hsv_mean': (0, 0, 0), 'rgb_mean': (0, 0, 0),
        'pixel_count': 0, 'center': (cx, cy), 'cell_bounds': (0, 0, 0, 0),
        'radius': 0, 'detected': False, 'crop': crop,
    }


def circular_mean_hue(hues):
    a = hues.astype(np.float64) * (2*np.pi/180)
    return float(np.arctan2(np.mean(np.sin(a)), np.mean(np.cos(a))) * (180/(2*np.pi)) % 180)


def circular_median_hue(hues):
    if np.any(hues < 30) and np.any(hues > 150):
        return float((np.median((hues.astype(np.int32)+90)%180) - 90) % 180)
    return float(np.median(hues))
