# Reference Classification - WhatsApp Image 2026-02-05 at 14.15.10.jpeg

## Visual Analysis (Human Classification)

### Well-by-Well Classification
```
        1     2     3     4     5     6     7     8     9    10    11    12
    +-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+
A   | PINK| PINK| PINK| PUR | PUR | PUR | PUR | PUR | PUR | PUR | PUR | PUR |  AND
    +-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+
B   | PINK| PINK| PINK| PINK| PUR | PUR | PUR | PUR | PUR | PUR | PUR | PUR |  MIF
    +-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+
C   | PINK| PINK| PINK| PINK| PINK| PUR | PUR | PUR | PUR | PUR | PUR | PUR |  CAS
    +-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+
D   | PUR | PUR | PUR | PUR | PUR | PUR | PUR | PUR | PUR | PUR | PUR | PUR |  POS
    +-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+
E   | PINK| PINK| PINK| PINK| PINK| PUR | PUR | PUR | PUR | PUR | PUR | PUR |  VOR
    +-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+
F   | PINK| PINK| PINK| PUR | PUR | PUR | PUR | PUR | PUR | PUR | PUR | PUR |  ITR
    +-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+
G   | PINK| PINK| PINK| PINK| PINK| PINK| PINK| PINK| PINK| PINK| PUR | PUR |  FLU
    +-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+
H   | PINK| PINK| PINK| PINK| PINK| PINK| PINK| PINK| PUR | PUR | PUR | PUR |  AMB
    +-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+
      (K)                                                                    (control)
```

### Expected MIC Values

| Row | Drug | First Purple Col | Concentration | Expected MIC |
|-----|------|------------------|---------------|--------------|
| A   | AND  | 4                | 0.032 mg/L    | **0.032**    |
| B   | MIF  | 5                | 0.064 mg/L    | **0.064**    |
| C   | CAS  | 6                | 0.125 mg/L    | **0.125**    |
| D   | POS  | 1                | ≤0.004 mg/L   | **≤0.004**   |
| E   | VOR  | 6                | 0.125 mg/L    | **0.125**    |
| F   | ITR  | 4                | 0.032 mg/L    | **0.032**    |
| G   | FLU  | 11               | 64 mg/L       | **64**       |
| H   | AMB  | 9                | 1 mg/L        | **1**        |

### Concentration Reference (Columns 1-12)

**Rows A-F (AND, MIF, CAS, POS, VOR, ITR):** 0.004 -> 8 mg/L
| Col | 1     | 2     | 3     | 4     | 5     | 6     | 7    | 8   | 9 | 10 | 11 | 12 |
|-----|-------|-------|-------|-------|-------|-------|------|-----|---|----|----|-----|
| mg/L| 0.004 | 0.008 | 0.016 | 0.032 | 0.064 | 0.125 | 0.25 | 0.5 | 1 | 2  | 4  | 8   |

**Row G (FLU):** 0.064 -> 128 mg/L
| Col | 1     | 2     | 3    | 4   | 5 | 6 | 7 | 8 | 9  | 10 | 11 | 12  |
|-----|-------|-------|------|-----|---|---|---|---|----|----|-----|-----|
| mg/L| 0.064 | 0.125 | 0.25 | 0.5 | 1 | 2 | 4 | 8 | 16 | 32 | 64  | 128 |

**Row H (AMB):** K(control), 0.008 -> 8 mg/L
| Col | 1 | 2     | 3     | 4     | 5     | 6     | 7    | 8   | 9 | 10 | 11 | 12 |
|-----|---|-------|-------|-------|-------|-------|------|-----|---|----|----|-----|
| mg/L| K | 0.008 | 0.016 | 0.032 | 0.064 | 0.125 | 0.25 | 0.5 | 1 | 2  | 4  | 8   |

---

## Comparison: PDF Report vs Reference

| Drug | PDF Report | Reference | Status |
|------|------------|-----------|--------|
| AND  | >8.0       | 0.032     | **WRONG** - Row A clearly shows purple from col 4 |
| MIF  | 0.064      | 0.064     | CORRECT |
| CAS  | 0.125      | 0.125     | CORRECT |
| **POS**  | 0.008      | **≤0.004**    | **WRONG** - All wells are purple, D1 included |
| VOR  | 0.125      | 0.125     | CORRECT |
| ITR  | 0.064      | 0.032     | **WRONG** - Purple starts at col 4, not col 5 |
| **FLU**  | 32         | **64**        | **WRONG** - Purple starts at col 11, not col 10 |
| **AMB**  | >8.0       | **1**         | **WRONG** - H9-H12 are purple, not pink |

## Issues Identified

1. **5 out of 8 ROWS ARE WRONG** - 37.5% accuracy (MIF, CAS, VOR correct)
2. **Row A (AND)**: All wells classified as PINK when cols 4-12 are PURPLE
3. **Row D (POS)**: D1 classified as PINK when it's PURPLE (entire row is purple)
4. **Row H (AMB)**: H9-H12 classified as PINK when they're PURPLE
5. **Columns 9-12**: Consistently misclassified as PINK across multiple rows
6. **Systematic shift**: MIC values are consistently higher than actual

## Root Cause (IDENTIFIED & FIXED)

The Flutter image processing had **naive grid extraction** that assumed the image was perfectly cropped:

```dart
// OLD CODE - WRONG:
final cellWidth = image.width / _cols;   // Divides ENTIRE image by 12
final cellHeight = image.height / _rows; // Divides ENTIRE image by 8
```

This caused the algorithm to sample colors from WRONG POSITIONS when the image had margins (plate frame, background).

### Fix Applied (v4)

Created new files ported from Python prototype:

1. **`plate_detector.dart`** - Detects and crops plate region using:
   - Sobel edge detection
   - Edge projection analysis
   - Color-based well detection
   - Fallback center crop with correct aspect ratio

2. **`well_extractor.dart`** - Robust well extraction using:
   - Gradient-based circle detection
   - Robust grid fitting with least squares
   - Pairwise distance analysis for step estimation
   - RANSAC-style outlier removal

3. **`image_processing_service.dart`** - Updated to:
   - Use PlateDetector to crop plate region first
   - Use WellExtractor for robust well finding
   - Added monotonicity enforcement (once purple, always purple to the right)
