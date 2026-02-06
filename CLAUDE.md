# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

MIC YST Plate Reader - A mobile application for analyzing 96-well microplate images to determine Minimum Inhibitory Concentration (MIC) values for antifungal susceptibility testing. Uses Alamar Blue (resazurin) colorimetric indicator chemistry where **pink = growth** and **purple/blue = inhibition**.

## Project Structure

- `lib/` - Flutter mobile app (main implementation)
- `files/` - Python prototype (reference implementation)
- `docs/planning.md` - Feature planning and architecture
- `work_on_this/` - Regulatory documents (EUCAST, kit manuals)
- `test_images/` - Sample plate images for testing

## Commands

### Flutter App
```bash
# Get dependencies
flutter pub get

# Run on device/simulator
flutter run

# Build for web (testing)
flutter build web

# Analyze code
flutter analyze lib/
```

### Python Prototype (Reference)
```bash
# Requires conda environment: mic_analyzer
source ~/miniconda3/etc/profile.d/conda.sh && conda activate mic_analyzer
python files/main.py <image_path> [--output-dir <dir>]
```

## Flutter Architecture

```
lib/
├── main.dart              # Entry point with Provider setup
├── app.dart               # MaterialApp with routing, theme, i18n
├── core/
│   ├── constants/         # app_colors, drug_concentrations, app_strings
│   └── theme/             # app_theme (Material 3)
├── l10n/                  # Localization (EN/TR)
│   ├── app_en.arb
│   ├── app_tr.arb
│   └── generated/         # Auto-generated localization files
├── providers/             # State management (Provider)
│   ├── locale_provider.dart
│   └── user_provider.dart
├── screens/               # UI screens
│   ├── onboarding/
│   └── home/
├── services/              # Business logic (TODO)
├── data/                  # Models, repositories (TODO)
└── widgets/               # Shared components (TODO)
```

### Key Dependencies
- `provider` - State management
- `camera` - Plate image capture
- `image` - Image processing
- `sqflite` - Local database
- `pdf`, `printing` - Report export

### Plate Configuration (lib/core/constants/drug_concentrations.dart)

| Row | Drug | Concentration Range |
|-----|------|---------------------|
| A-F | AND, MIF, CAS, POS, VOR, ITR | 0.004 → 8 mg/L |
| G | FLU | 0.064 → 128 mg/L |
| H | AMB | K(control), 0.008 → 8 mg/L |

**H1 is the positive control well (K)** - must show pink/growth for valid results.

## Development Phases

- [x] Phase 1: Python prototype (files/)
- [x] Phase 2: Flutter project setup
- [ ] Phase 3: Core features (camera, image processing, results)
- [ ] Phase 4: Data & history
- [ ] Phase 5: Export & polish

## Reference Materials

- `docs/planning.md` - Full feature planning and UI wireframes
- `work_on_this/` - Kit documentation, EUCAST breakpoints, lab manual (Turkish)
