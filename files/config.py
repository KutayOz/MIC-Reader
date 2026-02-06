"""
MIC YST Plate Reader - Configuration
Plate layout and concentration mappings from the kit documentation (7005 MIC YST).
"""

# Plate dimensions
ROWS = 8
COLS = 12

# Row labels
ROW_LABELS = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H']

# Antifungal agents per row
ANTIFUNGALS = {
    'A': 'AND',  # Anidulafungin
    'B': 'MIF',  # Micafungin
    'C': 'CAS',  # Caspofungin
    'D': 'POS',  # Posaconazole
    'E': 'VOR',  # Voriconazole
    'F': 'ITR',  # Itraconazole
    'G': 'FLU',  # Fluconazole
    'H': 'AMB',  # Amphotericin B
}

ANTIFUNGAL_FULL_NAMES = {
    'AND': 'Anidulafungin',
    'MIF': 'Micafungin',
    'CAS': 'Caspofungin',
    'POS': 'Posaconazole',
    'VOR': 'Voriconazole',
    'ITR': 'Itraconazole',
    'FLU': 'Fluconazole',
    'AMB': 'Amphotericin B',
}

# Concentrations (mg/L) per column for each row
# Rows A-F: 0.004 → 8
# Row G (FLU): 0.064 → 128
# Row H (AMB): K(control), 0.008 → 8
CONCENTRATIONS = {
    'A': [0.004, 0.008, 0.016, 0.032, 0.064, 0.125, 0.25, 0.5, 1, 2, 4, 8],
    'B': [0.004, 0.008, 0.016, 0.032, 0.064, 0.125, 0.25, 0.5, 1, 2, 4, 8],
    'C': [0.004, 0.008, 0.016, 0.032, 0.064, 0.125, 0.25, 0.5, 1, 2, 4, 8],
    'D': [0.004, 0.008, 0.016, 0.032, 0.064, 0.125, 0.25, 0.5, 1, 2, 4, 8],
    'E': [0.004, 0.008, 0.016, 0.032, 0.064, 0.125, 0.25, 0.5, 1, 2, 4, 8],
    'F': [0.004, 0.008, 0.016, 0.032, 0.064, 0.125, 0.25, 0.5, 1, 2, 4, 8],
    'G': [0.064, 0.125, 0.25, 0.5, 1, 2, 4, 8, 16, 32, 64, 128],
    'H': [None, 0.008, 0.016, 0.032, 0.064, 0.125, 0.25, 0.5, 1, 2, 4, 8],  # Col 1 = K (control)
}

# H1 is the positive control well (K)
CONTROL_WELL = ('H', 0)  # Row H, Column index 0

# MIC reading rules per antifungal type:
# AMB: 90% inhibition threshold
# Others: 50% inhibition threshold
INHIBITION_THRESHOLDS = {
    'AND': 0.50,
    'MIF': 0.50,
    'CAS': 0.50,
    'POS': 0.50,
    'VOR': 0.50,
    'ITR': 0.50,
    'FLU': 0.50,
    'AMB': 0.90,
}

# --- Image Processing Parameters ---

# Well extraction: fraction of cell used as circular mask (center region)
# 0.5 means use inner 50% radius to avoid edge reflections
WELL_MASK_RADIUS_FRACTION = 0.45

# Specular reflection threshold (V channel in HSV)
# Pixels above this value are considered reflections and excluded
SPECULAR_V_THRESHOLD = 245

# Minimum saturation for a valid color reading
MIN_SATURATION = 15

# --- Color Classification (HSV ranges, OpenCV scale: H=0-179, S=0-255, V=0-255) ---
# These are absolute fallback thresholds; primary method is relative scoring

# Pink/Growth: Hue roughly in the red-pink range
PINK_HUE_RANGE = (140, 179)  # plus wrap-around (0, 10)
PINK_HUE_RANGE_LOW = (0, 12)

# Purple/Blue/Inhibition: Hue in the blue-purple range
PURPLE_HUE_RANGE = (100, 145)

# --- Relative scoring weights ---
# How much to weight relative vs absolute classification
RELATIVE_WEIGHT = 0.65
ABSOLUTE_WEIGHT = 0.35
