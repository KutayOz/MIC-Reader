"""
Plate Detector - Finds the 96-well plate region in the image.
For top-down shots, performs light alignment and cropping.
"""

import cv2
import numpy as np


def detect_plate(image: np.ndarray) -> np.ndarray:
    """
    Detect the microplate region and return a cropped, aligned image.
    
    Strategy:
    1. Convert to grayscale, blur, edge detect
    2. Find the largest rectangular contour (the plate)
    3. Apply perspective transform if needed
    4. Return cropped plate image
    """
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    blurred = cv2.GaussianBlur(gray, (5, 5), 0)
    
    # Adaptive thresholding to find plate edges
    edges = cv2.Canny(blurred, 30, 100)
    
    # Dilate to connect edge fragments
    kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (5, 5))
    edges = cv2.dilate(edges, kernel, iterations=2)
    
    contours, _ = cv2.findContours(edges, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    
    if not contours:
        print("[WARN] No contours found, using full image as plate region")
        return image.copy()
    
    # Sort by area, pick the largest
    contours = sorted(contours, key=cv2.contourArea, reverse=True)
    
    plate_contour = None
    for cnt in contours[:5]:
        # Approximate to polygon
        peri = cv2.arcLength(cnt, True)
        approx = cv2.approxPolyDP(cnt, 0.02 * peri, True)
        
        if len(approx) == 4:
            plate_contour = approx
            break
    
    if plate_contour is not None:
        # Order points: top-left, top-right, bottom-right, bottom-left
        pts = order_points(plate_contour.reshape(4, 2))
        warped = four_point_transform(image, pts)
        return warped
    else:
        # Fallback: use bounding rect of largest contour
        x, y, w, h = cv2.boundingRect(contours[0])
        # Add small padding
        pad = 5
        x = max(0, x - pad)
        y = max(0, y - pad)
        w = min(image.shape[1] - x, w + 2 * pad)
        h = min(image.shape[0] - y, h + 2 * pad)
        
        aspect = w / h
        # 96-well plate aspect ratio is ~1.5 (127.76mm x 85.48mm)
        if 1.2 < aspect < 1.8:
            return image[y:y+h, x:x+w].copy()
        else:
            print("[WARN] Could not find plate rectangle, using full image")
            return image.copy()


def order_points(pts: np.ndarray) -> np.ndarray:
    """Order 4 points as: top-left, top-right, bottom-right, bottom-left."""
    rect = np.zeros((4, 2), dtype=np.float32)
    
    s = pts.sum(axis=1)
    rect[0] = pts[np.argmin(s)]   # top-left has smallest sum
    rect[2] = pts[np.argmax(s)]   # bottom-right has largest sum
    
    d = np.diff(pts, axis=1)
    rect[1] = pts[np.argmin(d)]   # top-right has smallest difference
    rect[3] = pts[np.argmax(d)]   # bottom-left has largest difference
    
    return rect


def four_point_transform(image: np.ndarray, pts: np.ndarray) -> np.ndarray:
    """Apply perspective transform using 4 ordered corner points."""
    (tl, tr, br, bl) = pts
    
    # Compute new width
    w1 = np.linalg.norm(br - bl)
    w2 = np.linalg.norm(tr - tl)
    max_w = int(max(w1, w2))
    
    # Compute new height
    h1 = np.linalg.norm(tr - br)
    h2 = np.linalg.norm(tl - bl)
    max_h = int(max(h1, h2))
    
    dst = np.array([
        [0, 0],
        [max_w - 1, 0],
        [max_w - 1, max_h - 1],
        [0, max_h - 1]
    ], dtype=np.float32)
    
    M = cv2.getPerspectiveTransform(pts, dst)
    warped = cv2.warpPerspective(image, M, (max_w, max_h))
    
    return warped
