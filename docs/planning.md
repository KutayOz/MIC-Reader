# MIC Plate Reader - Flutter Mobile App Planning

## Project Overview

**Goal:** Transform a web-based MIC (Minimum Inhibitory Concentration) plate reader into a professional Flutter mobile application for antifungal susceptibility testing.

**Target Users:** Laboratory technicians and microbiologists who need to analyze 96-well microtiter plates for antifungal drug testing.

---

## Blueprint Analysis (old_files)

### Original Implementation
- **Technology:** React-based single HTML file
- **Analysis Method:** Sends images to Claude API for color detection
- **Plate Format:** 8 rows × 12 columns (96 wells)

### Plate Structure
| Row | Drug | Concentration Range |
|-----|------|---------------------|
| A | AND (Anidulafungin) | 0.004 - 8 µg/mL |
| B | MIF (Micafungin) | 0.004 - 8 µg/mL |
| C | CAS (Caspofungin) | 0.004 - 8 µg/mL |
| D | POS (Posaconazole) | 0.004 - 8 µg/mL |
| E | VOR (Voriconazole) | 0.004 - 8 µg/mL |
| F | ITR (Itraconazole) | 0.004 - 8 µg/mL |
| G | FLU (Fluconazole) | 0.064 - 128 µg/mL |
| H | AMB (Amphotericin B) | 0 - 8 µg/mL |

### Color Interpretation
- **Pink/Light:** Fungal growth (no inhibition)
- **Purple/Blue:** Inhibition (no growth)
- **MIC Value:** First concentration where color transitions from pink to purple

### Supported Organisms (EUCAST Breakpoints)
- C. albicans
- C. auris
- C. dubliniensis
- C. glabrata
- C. krusei
- C. parapsilosis
- C. tropicalis
- C. guilliermondii
- Cryptococcus neoformans

---

## Requirements & Constraints

### Lighting & Image Capture
- **Constraint:** Flashlight ON by default (mandatory for consistent lighting)
- **Warning:** Display explicit warning to users that results are guidance only - manual verification recommended
- **Consideration:** Potential reflection issues from flashlight - may need anti-glare guidance

### Processing Mode
- **Type:** Capture-then-analyze (not real-time)
- **Storage:** Save photos to app-specific gallery with corresponding results
- **Traceability:** Professional workflow with history tracking

### Accuracy & User Interaction
- **Uncertainty Handling:** When model confidence is low, highlight uncertain wells
- **Manual Override:** Allow users to correct/modify uncertain classifications
- **Transparency:** Show confidence levels for each well classification

### Connectivity
- **Primary Mode:** Fully offline local processing
- **Sharing Feature:** Export/share results via 3rd party apps (WhatsApp, email, etc.)

---

## Core Features

### 0. Onboarding & User Profile
- [ ] First-run detection
- [ ] Name entry (required)
- [ ] Institution entry (optional)
- [ ] Language selection (Turkish/English)
- [ ] Profile persistence (local storage)
- [ ] Profile editing in settings

### 1. Camera & Capture
- [ ] Camera integration with flashlight control
- [ ] Auto-flashlight ON as default
- [ ] Capture guidance overlay (plate alignment guide)
- [ ] Image quality validation before processing

### 2. Image Processing Pipeline
- [ ] Local image analysis (no cloud dependency)
- [ ] Well detection (96 wells identification)
- [ ] Color classification (pink vs purple)
- [ ] Confidence scoring per well
- [ ] MIC value calculation per drug row

### 3. Results & Interpretation
- [ ] Visual plate representation with color-coded wells
- [ ] MIC values display for each antibiotic
- [ ] EUCAST interpretation (S/I/R) based on selected organism
- [ ] Uncertainty indicators for low-confidence wells
- [ ] Manual correction interface

### 4. Data Management
- [ ] App-specific gallery for captured images
- [ ] Results history with timestamps
- [ ] Link between images and their results
- [ ] Search/filter historical results

### 5. Sharing & Export
- [ ] Share results via WhatsApp, email, etc.
- [ ] Export formats: Image + text summary, PDF report
- [ ] Include plate image with annotated results

### 6. Organism Selection
- [ ] Organism picker with all supported species
- [ ] EUCAST breakpoint lookup
- [ ] Handle IE (Insufficient Evidence) cases
- [ ] Special notes for Note2/Note3 cases

---

## Image Processing Approach

### Recommended Pipeline

```
┌─────────────────────────────────────────────────────────────────┐
│                    IMAGE PROCESSING PIPELINE                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. CAPTURE                                                      │
│     └── Camera + Flashlight → Raw Image                         │
│                                                                  │
│  2. PRE-PROCESSING                                               │
│     ├── Gaussian Blur (3x3 kernel) → Noise reduction            │
│     ├── White Balance Correction → Handle lighting variance      │
│     └── CLAHE (optional) → Enhance contrast                     │
│                                                                  │
│  3. WELL DETECTION                                               │
│     ├── Hough Circle Transform → Detect circular wells          │
│     ├── Validate 96 wells found (8×12 grid)                     │
│     └── Extract ROI for each well                               │
│                                                                  │
│  4. COLOR ANALYSIS (per well)                                    │
│     ├── RGB → HSV conversion                                    │
│     ├── Calculate mean/median HSV values                        │
│     ├── Classify: Pink (Hue ~330-30°) vs Purple (Hue ~260-290°) │
│     └── Calculate confidence score                              │
│                                                                  │
│  5. MIC DETERMINATION                                            │
│     ├── Find transition point per row (pink → purple)           │
│     ├── Map to concentration value                              │
│     └── Flag uncertain transitions                              │
│                                                                  │
│  6. INTERPRETATION                                               │
│     ├── Apply EUCAST breakpoints                                │
│     ├── Classify as S (Susceptible), I (Intermediate), R        │
│     └── Handle IE/special cases                                 │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Color Classification Strategy

**Primary Approach: HSV Thresholding**
- Simple, fast, interpretable
- Well-suited for distinct pink vs purple differentiation

**HSV Ranges (Initial Estimates - Requires Calibration)**
```
Pink (Growth):
  - Hue: 330° - 360° OR 0° - 30°
  - Saturation: > 30%
  - Value: > 40%

Purple (Inhibition):
  - Hue: 260° - 290°
  - Saturation: > 30%
  - Value: > 30%

Empty/Unclear:
  - Low saturation OR outside defined hue ranges
```

**Confidence Scoring**
- High confidence: Color clearly within expected range
- Medium confidence: Color at boundary of ranges
- Low confidence: Ambiguous color, flagged for user review

### Methods NOT Needed
| Method | Reason |
|--------|--------|
| Edge Detection (Canny/Sobel) | Not useful - we need color, not edges |
| Heavy Blurring | Loses color information |
| Deep CNN | Overkill for binary color classification |
| Real-time processing | User captures then analyzes |

---

## Technical Stack (Proposed)

### Framework
- **Flutter/Dart** - Cross-platform mobile development

### Key Packages (To Evaluate)
| Purpose | Package Options |
|---------|-----------------|
| Camera | `camera`, `camera_awesome` |
| Image Processing | `image`, `opencv_flutter`, native code via platform channels |
| Local Storage | `sqflite`, `hive`, `isar` |
| File Management | `path_provider`, `share_plus` |
| PDF Export | `pdf`, `printing` |
| State Management | `riverpod`, `bloc`, or `provider` |

### Performance Considerations
- Heavy image processing may need native code (Swift/Kotlin) via platform channels
- Consider isolates for background processing
- Optimize for mid-range devices

---

## UI/UX Principles

### Design Goals
- **Professional:** Clean, clinical aesthetic suitable for lab environment
- **User-Friendly:** Intuitive workflow, minimal learning curve
- **Efficient:** Quick capture-to-results flow
- **Portable:** Works well on various screen sizes

### Key Screens (Proposed)
1. **Home/Dashboard** - Quick capture button, recent results
2. **Camera/Capture** - Alignment guide, flashlight control
3. **Analysis/Results** - Plate visualization, MIC values, confidence indicators
4. **Manual Correction** - Tap wells to change classification
5. **History/Gallery** - Browse past analyses
6. **Settings** - Default organism, export preferences

### Accessibility
- Clear color contrast (not relying solely on pink/purple distinction)
- Text labels for all color-coded elements
- Support for larger text sizes

---

## Decisions Made

### Technical Decisions
| Question | Decision |
|----------|----------|
| Device support | Older devices: Android 8+ (API 26), iOS 12+ |
| Landscape mode | TBD |
| State management | TBD (see explanation below) |
| Language support | Turkish + English (i18n) |
| Batch processing | Single plate, but architecture supports future multi-batch |

### Open Questions (Remaining)
- Should results include lab/technician identification?
- Tutorial/onboarding flow needed?
- Any regulatory considerations (IVD, CE marking)?
- Camera calibration per device?

---

## Development Phases

### Phase 1: Algorithm Prototyping (Current)
- [x] Create Python prototype script
- [ ] Test on sample image
- [ ] Tune HSV color ranges for pink/purple detection
- [ ] Tune Hough circle detection parameters
- [ ] Validate MIC calculation logic
- [ ] Test with additional sample images

**Location:** `prototypes/mic_plate_analyzer.py`

**Run with:**
```bash
cd prototypes
pip install -r requirements.txt
python mic_plate_analyzer.py
```

### Phase 2: Flutter Project Setup
- [ ] Initialize Flutter project
- [ ] Set up folder structure (as defined in Architecture section)
- [ ] Configure dependencies (Provider, camera, etc.)
- [ ] Set up i18n (Turkish/English)
- [ ] Create theme and color constants

### Phase 3: Core Features
- [ ] Onboarding screen (name entry)
- [ ] Camera integration with flashlight
- [ ] Native OpenCV integration via platform channels
- [ ] Port algorithm from Python prototype
- [ ] Results display with plate visualization

### Phase 4: Data & History
- [ ] Local database setup
- [ ] Save/load analysis results
- [ ] Gallery/history screen
- [ ] Link images with results

### Phase 5: Polish & Export
- [ ] Manual well correction UI
- [ ] Confidence indicators
- [ ] Share/export functionality (PDF, image)
- [ ] Settings screen
- [ ] Testing and refinement

---

---

## Color Chemistry Research

### Plate Type Identified
The sample image appears to be a **Sensititre YeastOne** plate, which uses **Alamar Blue (resazurin)** as the colorimetric indicator.

### Color Change Mechanism

```
┌─────────────────────────────────────────────────────────────────┐
│                    ALAMAR BLUE COLOR CHEMISTRY                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   Resazurin (oxidized)                Resorufin (reduced)       │
│   ┌──────────────┐                    ┌──────────────┐          │
│   │              │    Metabolic       │              │          │
│   │  BLUE/PURPLE │ ──────────────►    │    PINK      │          │
│   │              │    Activity        │              │          │
│   └──────────────┘    (Growth)        └──────────────┘          │
│                                                                  │
│   = NO GROWTH                         = GROWTH                   │
│   = INHIBITION                        = VIABLE CELLS             │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Color Interpretation for MIC
| Color | Meaning | Indicator State |
|-------|---------|-----------------|
| Blue | No growth | Resazurin (oxidized) |
| Purple | Minimal/no growth | Resazurin (partially reduced) |
| Pink | Growth | Resorufin (reduced) |

### MIC Determination Rule
**MIC = First well (lowest concentration) where color is BLUE or PURPLE**
- Reading left to right (increasing concentration)
- Pink wells indicate fungal growth (drug not effective at that concentration)
- Blue/purple wells indicate inhibition (drug is effective)

### Spectral Properties (for algorithm calibration)
| Compound | Color | Absorption Peak |
|----------|-------|-----------------|
| Resazurin | Blue | ~600 nm |
| Resorufin | Pink/Red | ~570 nm |

### Sources
- [Sensititre YeastOne Clinical Evaluation (PMC)](https://pmc.ncbi.nlm.nih.gov/articles/PMC522344/)
- [Automated Plate Reading with Mobile Phone (PMC)](https://pmc.ncbi.nlm.nih.gov/articles/PMC5156953/)
- [ResearchGate: Alamar Blue Color Change](https://www.researchgate.net/post/Does_anyone_have_information_about_the_color_change_during_Anti-TB_test_by_Alamar_Blue_Dye_method)

---

## State Management Explanation

### What is State Management?

In mobile apps, "state" refers to **data that can change over time** and affects what the user sees. For example:
- Which organism is currently selected?
- What colors are assigned to each well?
- Is the app currently processing an image?
- What results are stored in history?

**State management** is how we organize, update, and share this data across different screens and components.

### Why Does It Matter?

Without proper state management:
- Data can get out of sync between screens
- Code becomes messy and hard to maintain
- Bugs are harder to track down
- Adding new features becomes difficult

### Options for Flutter

| Approach | Complexity | Best For |
|----------|------------|----------|
| **Provider** | Simple | Small-medium apps, easy to learn |
| **Riverpod** | Medium | Safer Provider, better testing |
| **BLoC** | Complex | Large apps, strict patterns |

### Recommendation for This Project

**Provider** or **Riverpod** would be suitable:
- App is medium complexity
- Clear data flow needed (camera → processing → results → history)
- Both support dependency injection for testability
- Both work well with older devices

**Decision: Provider** - Simple, widely used, easy to learn. Can refactor later if needed.

---

---

## App Architecture

### Folder Structure

```
lib/
├── main.dart                      # App entry point
├── app.dart                       # MaterialApp configuration, routes
│
├── core/                          # Shared utilities & constants
│   ├── constants/
│   │   ├── app_colors.dart        # Color palette
│   │   ├── app_strings.dart       # Static strings (non-i18n)
│   │   ├── drug_concentrations.dart # MIC concentration values
│   │   └── eucast_breakpoints.dart  # EUCAST data tables
│   ├── theme/
│   │   └── app_theme.dart         # Light/dark themes
│   ├── utils/
│   │   ├── image_utils.dart       # Image processing helpers
│   │   ├── color_classifier.dart  # HSV color classification
│   │   └── file_utils.dart        # Save/load helpers
│   └── extensions/
│       └── context_extensions.dart # Convenience extensions
│
├── l10n/                          # Localization (i18n)
│   ├── app_en.arb                 # English strings
│   └── app_tr.arb                 # Turkish strings
│
├── data/                          # Data layer
│   ├── models/
│   │   ├── user_profile.dart      # User name, preferences
│   │   ├── plate_analysis.dart    # Single analysis result
│   │   ├── well_result.dart       # Individual well data
│   │   ├── mic_result.dart        # MIC value + interpretation
│   │   └── organism.dart          # Organism with breakpoints
│   ├── repositories/
│   │   ├── analysis_repository.dart    # Save/load analyses
│   │   ├── user_repository.dart        # User profile persistence
│   │   └── settings_repository.dart    # App settings
│   └── local/
│       └── database_helper.dart   # SQLite/Hive setup
│
├── services/                      # Business logic services
│   ├── camera_service.dart        # Camera control, capture
│   ├── image_processing_service.dart  # Main processing pipeline
│   ├── well_detection_service.dart    # Circle/well detection
│   ├── color_analysis_service.dart    # Color classification
│   ├── mic_calculator_service.dart    # MIC determination
│   └── export_service.dart        # PDF/image export, sharing
│
├── providers/                     # State management (Provider)
│   ├── user_provider.dart         # User profile state
│   ├── analysis_provider.dart     # Current analysis state
│   ├── history_provider.dart      # Past analyses
│   ├── camera_provider.dart       # Camera state
│   └── settings_provider.dart     # App settings state
│
├── screens/                       # UI Screens
│   ├── onboarding/
│   │   └── onboarding_screen.dart # First-run name entry
│   ├── home/
│   │   └── home_screen.dart       # Dashboard
│   ├── camera/
│   │   ├── camera_screen.dart     # Capture interface
│   │   └── widgets/
│   │       ├── plate_guide_overlay.dart  # Alignment guide
│   │       └── flash_control.dart        # Flashlight toggle
│   ├── analysis/
│   │   ├── analysis_screen.dart   # Processing & results
│   │   └── widgets/
│   │       ├── plate_grid.dart    # Interactive 96-well display
│   │       ├── well_widget.dart   # Single well (tappable)
│   │       ├── mic_result_card.dart  # Drug result card
│   │       └── confidence_indicator.dart # Uncertainty display
│   ├── correction/
│   │   └── correction_screen.dart # Manual well editing
│   ├── history/
│   │   ├── history_screen.dart    # Gallery of past analyses
│   │   └── widgets/
│   │       └── history_card.dart  # Single history item
│   ├── detail/
│   │   └── detail_screen.dart     # Full analysis detail view
│   └── settings/
│       └── settings_screen.dart   # Preferences
│
└── widgets/                       # Shared/reusable widgets
    ├── app_button.dart
    ├── app_card.dart
    ├── loading_overlay.dart
    ├── organism_selector.dart
    └── language_switcher.dart
```

### Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         PRESENTATION                             │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐           │
│  │ Screens  │ │ Widgets  │ │ Providers│ │  Theme   │           │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └──────────┘           │
│       │            │            │                               │
├───────┼────────────┼────────────┼───────────────────────────────┤
│       │            │            │     BUSINESS LOGIC            │
│       │            │            ▼                               │
│       │            │     ┌─────────────┐                        │
│       │            │     │  Services   │                        │
│       │            │     │ - Camera    │                        │
│       │            │     │ - ImageProc │                        │
│       │            │     │ - MIC Calc  │                        │
│       │            │     │ - Export    │                        │
│       │            │     └──────┬──────┘                        │
│       │            │            │                               │
├───────┼────────────┼────────────┼───────────────────────────────┤
│       │            │            │     DATA LAYER                │
│       ▼            ▼            ▼                               │
│  ┌─────────────────────────────────────┐                        │
│  │           Repositories              │                        │
│  │  - Analysis  - User  - Settings     │                        │
│  └─────────────────┬───────────────────┘                        │
│                    │                                            │
│              ┌─────▼─────┐                                      │
│              │  Models   │                                      │
│              │  Local DB │                                      │
│              └───────────┘                                      │
└─────────────────────────────────────────────────────────────────┘
```

### Data Models

```dart
// user_profile.dart
class UserProfile {
  final String id;
  final String name;
  final String? institution;  // Optional: lab name
  final DateTime createdAt;
  final String preferredLanguage; // 'en' or 'tr'
  final String defaultOrganism;   // Default selection
}

// plate_analysis.dart
class PlateAnalysis {
  final String id;
  final String odUserId;         // Links to user
  final DateTime timestamp;
  final String imagePath;         // Local file path
  final String organism;          // Selected organism
  final List<WellResult> wells;   // 96 well results
  final List<MicResult> micResults; // 8 drug results
  final String? notes;            // Optional user notes
}

// well_result.dart
class WellResult {
  final int row;                  // 0-7 (A-H)
  final int column;               // 0-11 (1-12)
  final WellColor color;          // pink, purple, empty
  final double confidence;        // 0.0 - 1.0
  final bool manuallyEdited;      // User override flag
  final Map<String, double> hsvValues; // Raw color data
}

// mic_result.dart
class MicResult {
  final String drug;              // AND, MIF, CAS, etc.
  final double? micValue;         // µg/mL or null
  final Interpretation interpretation; // S, I, R, IE
  final String breakpointInfo;    // "S ≤0.06, R >0.25"
  final int? micWellIndex;        // Which column is MIC
}
```

---

## UI/UX Design

### Screen Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                        APP FLOW DIAGRAM                          │
└─────────────────────────────────────────────────────────────────┘

                         ┌─────────────┐
                         │  App Start  │
                         └──────┬──────┘
                                │
                                ▼
                    ┌───────────────────────┐
                    │  First Run Check      │
                    │  (User exists?)       │
                    └───────────┬───────────┘
                                │
              ┌─────────────────┴─────────────────┐
              │ NO                                │ YES
              ▼                                   ▼
    ┌─────────────────┐                 ┌─────────────────┐
    │   ONBOARDING    │                 │      HOME       │
    │  - Enter name   │                 │   - Welcome     │
    │  - Select lang  │────────────────►│   - New capture │
    │  - Tutorial?    │                 │   - History     │
    └─────────────────┘                 └────────┬────────┘
                                                 │
                        ┌────────────────────────┼────────────────┐
                        │                        │                │
                        ▼                        ▼                ▼
              ┌─────────────────┐      ┌─────────────┐   ┌────────────┐
              │     CAMERA      │      │   HISTORY   │   │  SETTINGS  │
              │  - Alignment    │      │  - Gallery  │   │  - Name    │
              │  - Flash ON     │      │  - Search   │   │  - Lang    │
              │  - Capture      │      │  - Filter   │   │  - Default │
              └────────┬────────┘      └──────┬──────┘   │    org     │
                       │                      │          └────────────┘
                       ▼                      │
              ┌─────────────────┐             │
              │    ANALYSIS     │◄────────────┘
              │  - Processing   │       (tap item)
              │  - Plate view   │
              │  - Results      │
              │  - Confidence   │
              └────────┬────────┘
                       │
          ┌────────────┼────────────┐
          │            │            │
          ▼            ▼            ▼
   ┌────────────┐ ┌─────────┐ ┌──────────┐
   │ CORRECTION │ │  SHARE  │ │   SAVE   │
   │ - Tap well │ │ - PDF   │ │ - Store  │
   │ - Change   │ │ - Image │ │ - Gallery│
   │   color    │ │ - Text  │ └──────────┘
   └────────────┘ └─────────┘
```

### Screen Wireframes

#### 1. Onboarding Screen (First Run)
```
┌─────────────────────────────────┐
│                                 │
│         🧬 MIC Reader           │
│                                 │
│    ┌───────────────────────┐    │
│    │  Welcome! / Hoş       │    │
│    │  geldiniz!            │    │
│    └───────────────────────┘    │
│                                 │
│    Your Name / Adınız:          │
│    ┌───────────────────────┐    │
│    │ Dr. Ayşe Yılmaz      │    │
│    └───────────────────────┘    │
│                                 │
│    Institution (optional):      │
│    ┌───────────────────────┐    │
│    │ Hacettepe Lab         │    │
│    └───────────────────────┘    │
│                                 │
│    Language / Dil:              │
│    ┌─────────┐ ┌─────────┐     │
│    │ English │ │ Türkçe  │     │
│    └─────────┘ └─────────┘     │
│                                 │
│    ┌───────────────────────┐    │
│    │      GET STARTED       │    │
│    │      BAŞLA             │    │
│    └───────────────────────┘    │
│                                 │
└─────────────────────────────────┘
```

#### 2. Home Screen
```
┌─────────────────────────────────┐
│ ☰                    ⚙️        │
├─────────────────────────────────┤
│                                 │
│  Welcome, Dr. Ayşe Yılmaz      │
│  Hacettepe Lab                  │
│                                 │
│  ┌───────────────────────────┐  │
│  │                           │  │
│  │      📸                   │  │
│  │                           │  │
│  │    NEW ANALYSIS           │  │
│  │    Yeni Analiz            │  │
│  │                           │  │
│  └───────────────────────────┘  │
│                                 │
│  Recent Results                 │
│  ─────────────────────────────  │
│  ┌───────────────────────────┐  │
│  │ 📋 C. albicans            │  │
│  │    Today, 14:32           │  │
│  │    8 drugs analyzed       │  │
│  └───────────────────────────┘  │
│  ┌───────────────────────────┐  │
│  │ 📋 C. auris               │  │
│  │    Yesterday, 09:15       │  │
│  │    8 drugs analyzed       │  │
│  └───────────────────────────┘  │
│                                 │
│  [View All History]             │
│                                 │
├─────────────────────────────────┤
│  🏠      📷      📜      ⚙️    │
│  Home   Capture History Settings│
└─────────────────────────────────┘
```

#### 3. Camera Screen
```
┌─────────────────────────────────┐
│ ←  Capture Plate      🔦 ON    │
├─────────────────────────────────┤
│                                 │
│  ┌───────────────────────────┐  │
│  │                           │  │
│  │    ╔═══════════════╗      │  │
│  │    ║  ○ ○ ○ ○ ○ ○  ║      │  │
│  │    ║  ○ ○ ○ ○ ○ ○  ║      │  │
│  │    ║  ○ ○ ○ ○ ○ ○  ║      │  │
│  │    ║  ○ ○ ○ ○ ○ ○  ║      │  │
│  │    ║  ○ ○ ○ ○ ○ ○  ║      │  │
│  │    ║  ○ ○ ○ ○ ○ ○  ║      │  │
│  │    ║  ○ ○ ○ ○ ○ ○  ║      │  │
│  │    ║  ○ ○ ○ ○ ○ ○  ║      │  │
│  │    ╚═══════════════╝      │  │
│  │     (alignment guide)      │  │
│  │                           │  │
│  └───────────────────────────┘  │
│                                 │
│  ⚠️ Keep flash ON for best     │
│     results                     │
│                                 │
│        ┌─────────────┐          │
│        │     ◉       │          │
│        │   CAPTURE   │          │
│        └─────────────┘          │
│                                 │
└─────────────────────────────────┘
```

#### 4. Analysis/Results Screen
```
┌─────────────────────────────────┐
│ ←  Analysis Results    💾 📤   │
├─────────────────────────────────┤
│                                 │
│  Organism: [C. albicans    ▼]   │
│                                 │
│  ┌───────────────────────────┐  │
│  │    1  2  3  4  5  6  ...  │  │
│  │ A  🟣🟣🟣🟣🟣🟣...       │  │
│  │ B  🔴🔴🟣🟣🟣🟣...       │  │
│  │ C  🔴🔴🔴⚠️🟣🟣...       │  │
│  │ D  🔴🔴🔴🔴🟣🟣...       │  │
│  │ ...                       │  │
│  └───────────────────────────┘  │
│  ⚠️ = uncertain, tap to edit   │
│                                 │
│  MIC Results                    │
│  ─────────────────────────────  │
│  ┌─────────┬─────────┬───────┐  │
│  │ AND     │ 0.016   │  S ✓  │  │
│  ├─────────┼─────────┼───────┤  │
│  │ MIF     │ 0.032   │  S ✓  │  │
│  ├─────────┼─────────┼───────┤  │
│  │ CAS     │ 0.125   │  R ✗  │  │
│  ├─────────┼─────────┼───────┤  │
│  │ ...     │ ...     │ ...   │  │
│  └─────────┴─────────┴───────┘  │
│                                 │
│  [Edit Wells]  [Save]  [Share]  │
│                                 │
└─────────────────────────────────┘
```

#### 5. Correction/Edit Screen
```
┌─────────────────────────────────┐
│ ←  Edit Wells          ✓ Done  │
├─────────────────────────────────┤
│                                 │
│  Tap a well to change color     │
│                                 │
│  ┌───────────────────────────┐  │
│  │    1  2  3  4  5  6  ...  │  │
│  │ A  🟣🟣🟣🟣🟣🟣...       │  │
│  │ B  🔴🔴🟣🟣🟣🟣...       │  │
│  │ C  🔴🔴🔴[⚠️]🟣🟣...     │  │ ← selected
│  │ D  🔴🔴🔴🔴🟣🟣...       │  │
│  │ ...                       │  │
│  └───────────────────────────┘  │
│                                 │
│  Selected: C4 (CAS - 0.032)     │
│  Confidence: 45% (Low)          │
│                                 │
│  Change to:                     │
│  ┌─────────┐  ┌─────────┐      │
│  │ 🔴 Pink │  │ 🟣Purple│      │
│  │ (Growth)│  │(No grow)│      │
│  └─────────┘  └─────────┘      │
│                                 │
│  ┌───────────────────────────┐  │
│  │     RECALCULATE MIC       │  │
│  └───────────────────────────┘  │
│                                 │
└─────────────────────────────────┘
```

#### 6. Share/Export Screen
```
┌─────────────────────────────────┐
│ ←  Share Results               │
├─────────────────────────────────┤
│                                 │
│  Export Format:                 │
│                                 │
│  ┌───────────────────────────┐  │
│  │ 📄 PDF Report             │  │
│  │    Full report with plate │  │
│  │    image and all results  │  │
│  └───────────────────────────┘  │
│                                 │
│  ┌───────────────────────────┐  │
│  │ 🖼️ Image + Summary        │  │
│  │    Annotated plate image  │  │
│  │    with text summary      │  │
│  └───────────────────────────┘  │
│                                 │
│  ┌───────────────────────────┐  │
│  │ 📋 Text Only              │  │
│  │    Plain text results     │  │
│  │    for quick sharing      │  │
│  └───────────────────────────┘  │
│                                 │
│  Include in export:             │
│  ☑️ Analyst name                │
│  ☑️ Institution                 │
│  ☑️ Timestamp                   │
│  ☐ Raw confidence values        │
│                                 │
│  ┌───────────────────────────┐  │
│  │      SHARE VIA...         │  │
│  └───────────────────────────┘  │
│                                 │
└─────────────────────────────────┘
```

### Color Palette

```
Primary:     #6366F1 (Indigo)     - Main actions, headers
Secondary:   #EC4899 (Pink)       - Growth indicator
Success:     #10B981 (Green)      - Susceptible (S)
Warning:     #F59E0B (Amber)      - Intermediate (I), Uncertain
Danger:      #EF4444 (Red)        - Resistant (R)
Purple:      #8B5CF6 (Violet)     - Inhibition indicator

Background:  #F8FAFC (Light gray)
Surface:     #FFFFFF (White)
Text:        #0F172A (Dark slate)
TextSecond:  #64748B (Gray)
```

---

## Updated HSV Color Ranges

Based on the Alamar Blue chemistry, refined color detection ranges:

```dart
// PINK (Growth - Resorufin)
// Hue: ~330-360° and 0-20° (wraps around)
// Saturation: > 25% (vivid color)
// Value: > 40% (not too dark)

// PURPLE/BLUE (Inhibition - Resazurin)
// Hue: ~240-300° (blue to purple range)
// Saturation: > 25%
// Value: > 30%

// UNCERTAIN
// Low saturation OR hue between ranges
// Flag for manual review
```

---

## Version History

| Date | Version | Notes |
|------|---------|-------|
| 2026-02-05 | 0.1 | Initial planning document created |
| 2026-02-05 | 0.2 | Added device support decisions, color chemistry research, state management explanation |
| 2026-02-05 | 0.3 | Added app architecture, folder structure, data models, UI/UX wireframes, onboarding feature |
| 2026-02-05 | 0.4 | Decision: Native OpenCV via platform channels. Python prototype first for algorithm testing. |

