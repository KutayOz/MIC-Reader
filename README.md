# MIC Plate Reader

<p align="center">
  <img src="docs/images/app_icon.png" alt="MIC Plate Reader" width="120"/>
</p>

<p align="center">
  <strong>Automated 96-Well Microplate Analysis for Antifungal Susceptibility Testing</strong>
</p>

<p align="center">
  <a href="#features">Features</a> •
  <a href="#how-it-works">How It Works</a> •
  <a href="#installation">Installation</a> •
  <a href="#usage">Usage</a> •
  <a href="#technical-details">Technical Details</a>
</p>

---

## Overview

MIC Plate Reader is a mobile application that automates the reading of 96-well microplates used in antifungal susceptibility testing. It uses computer vision and image processing to detect well colors (pink/purple) and determine Minimum Inhibitory Concentration (MIC) values based on the Alamar Blue (resazurin) colorimetric indicator.

> **Disclaimer**: Results are for guidance only. Manual verification by qualified personnel is recommended for clinical decisions.

## Features

- **Automated Well Detection**: Uses OpenCV HoughCircles for accurate 96-well grid detection
- **Color Classification**: Brightness-independent algorithm using normalized R-B ratio
- **MIC Calculation**: Automatic determination of MIC values for 8 antifungal drugs
- **EUCAST Interpretation**: S/I/R classification based on EUCAST breakpoints for 9 Candida species
- **Auto-Save**: Automatic saving of analysis results (configurable)
- **Patient Tracking**: Optional patient name input for result organization
- **Manual Correction**: Tap any well to manually correct color classification
- **Export Options**: Share results as PDF report or plain text
- **Bilingual**: English and Turkish language support
- **Offline**: Works completely offline after installation

## How It Works

### Alamar Blue Chemistry

The assay uses resazurin (Alamar Blue) as a colorimetric indicator:
- **Pink** = Growth (resazurin reduced to resorufin)
- **Purple/Blue** = Inhibition (resazurin remains oxidized)

### Plate Configuration

| Row | Drug | Abbreviation | Concentration Range |
|-----|------|--------------|---------------------|
| A | Anidulafungin | AND | 0.004 - 8 mg/L |
| B | Micafungin | MIF | 0.004 - 8 mg/L |
| C | Caspofungin | CAS | 0.004 - 8 mg/L |
| D | Posaconazole | POS | 0.004 - 8 mg/L |
| E | Voriconazole | VOR | 0.004 - 8 mg/L |
| F | Itraconazole | ITR | 0.004 - 8 mg/L |
| G | Fluconazole | FLU | 0.064 - 128 mg/L |
| H | Amphotericin B | AMB | K*, 0.008 - 8 mg/L |

*K = Positive control well (H1) - must show growth (pink) for valid results

### Detection Pipeline

```
Image Capture → Plate Detection → Perspective Correction → Well Detection → Color Classification → MIC Calculation
```

1. **Image Enhancement**: Auto white balance, gamma correction, CLAHE
2. **Plate Localization**: Edge detection and contour analysis
3. **Well Detection**: Multi-scale HoughCircles with color validation
4. **Color Classification**: Normalized R-B ratio for brightness independence
5. **MIC Determination**: First purple well in each row indicates MIC

## Screenshots

<p align="center">
  <img src="docs/images/screenshot_home.png" width="200" alt="Home Screen"/>
  <img src="docs/images/screenshot_camera.png" width="200" alt="Camera Screen"/>
  <img src="docs/images/screenshot_results.png" width="200" alt="Results Screen"/>
  <img src="docs/images/screenshot_history.png" width="200" alt="History Screen"/>
</p>

## Installation

### Requirements

- Android 6.0 (API 23) or higher
- Camera permission for plate capture
- ~120 MB storage space

### From Release

1. Download the latest APK from [Releases](../../releases)
2. Enable "Install from unknown sources" if prompted
3. Install and open the app

### From Source

```bash
# Clone the repository
git clone https://github.com/yourusername/mic-plate-reader.git
cd mic-plate-reader

# Install dependencies
flutter pub get

# Build release APK
export JAVA_HOME=/path/to/java17
flutter build apk --release

# APK will be at: build/app/outputs/flutter-apk/app-release.apk
```

## Usage

### Quick Start

1. **Enter Patient Name** (optional) on the home screen
2. **Tap "New Analysis"** to open camera
3. **Rotate phone to landscape** and align plate in frame
4. **Capture** the image
5. **Review results** - tap any well to correct if needed
6. **Select organism** for EUCAST interpretation
7. **Share/Export** as PDF or text

### Tips for Best Results

- Use good, even lighting (avoid shadows)
- Hold phone parallel to plate surface
- Ensure all wells are visible in frame
- Clean plate surface before capture
- Use flash in low-light conditions

### Settings

- **Auto-save**: Automatically save results after analysis (default: ON)
- **Language**: English or Turkish
- **Profile**: Set analyst name and institution for reports

## Technical Details

### Architecture

```
lib/
├── core/
│   ├── constants/     # Colors, drug configs, EUCAST breakpoints
│   └── theme/         # Material 3 theming
├── data/
│   ├── models/        # PlateAnalysis, WellResult, MicResult
│   └── repositories/  # SQLite persistence
├── l10n/              # Localization (EN/TR)
├── providers/         # State management (Provider)
├── screens/           # UI screens
│   ├── analysis/      # Results display and editing
│   ├── camera/        # Plate capture
│   ├── history/       # Saved analyses
│   ├── home/          # Main screen with settings
│   └── onboarding/    # First-run setup
└── services/
    ├── image_processing_service.dart  # Color classification
    ├── grid_fitter.dart               # Well grid detection
    ├── native_opencv.dart             # FFI bindings
    ├── interpretation_service.dart    # EUCAST S/I/R
    └── export_service.dart            # PDF/text export
```

### Key Technologies

- **Flutter**: Cross-platform UI framework
- **OpenCV**: Native C++ image processing via FFI
- **SQLite**: Local database for analysis history
- **Provider**: State management
- **PDF**: Report generation

### Color Classification Algorithm

The app uses a brightness-independent normalized R-B ratio:

```dart
normalizedRB = (R - B) / max(R, B)
// Range: -1 (pure blue) to +1 (pure red)

// Classification thresholds:
// normalizedRB > 0.08  → Pink (growth)
// normalizedRB < -0.02 → Purple (inhibition)
```

This approach correctly classifies both dark pink and light purple wells regardless of lighting conditions.

### EUCAST Breakpoints

Interpretation follows EUCAST Clinical Breakpoints v14.0 for:
- *C. albicans*
- *C. glabrata*
- *C. parapsilosis*
- *C. tropicalis*
- *C. krusei*
- *C. dubliniensis*
- *C. guilliermondii*
- *C. lusitaniae*
- *C. auris*

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- OpenCV team for the computer vision library
- EUCAST for antifungal breakpoint data
- Flutter team for the excellent framework

---

<p align="center">
  Made with Flutter
</p>
