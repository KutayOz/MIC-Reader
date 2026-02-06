// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'MIC Reader';

  @override
  String get welcome => 'Welcome';

  @override
  String welcomeBack(String name) {
    return 'Welcome back, $name';
  }

  @override
  String get onboardingTitle => 'Welcome to MIC Reader';

  @override
  String get onboardingSubtitle =>
      'Antifungal susceptibility testing made easy';

  @override
  String get enterYourName => 'Enter your name';

  @override
  String get nameHint => 'Dr. Name Surname';

  @override
  String get institution => 'Institution (optional)';

  @override
  String get institutionHint => 'Hospital/Laboratory name';

  @override
  String get selectLanguage => 'Select language';

  @override
  String get getStarted => 'Get Started';

  @override
  String get home => 'Home';

  @override
  String get capture => 'Capture';

  @override
  String get history => 'History';

  @override
  String get settings => 'Settings';

  @override
  String get newAnalysis => 'New Analysis';

  @override
  String get recentResults => 'Recent Results';

  @override
  String get viewAllHistory => 'View All History';

  @override
  String get noRecentResults => 'No recent results';

  @override
  String get capturePlate => 'Capture Plate';

  @override
  String get flashOn => 'Flash On';

  @override
  String get flashOff => 'Flash Off';

  @override
  String get captureHint => 'Align the plate within the guide and tap capture';

  @override
  String get flashWarning => 'Keep flash ON for best results';

  @override
  String get analyzing => 'Analyzing...';

  @override
  String get analysisResults => 'Analysis Results';

  @override
  String get selectOrganism => 'Select Organism';

  @override
  String get micResults => 'MIC Results';

  @override
  String get drug => 'Drug';

  @override
  String get micValue => 'MIC (mg/L)';

  @override
  String get interpretation => 'Interpretation';

  @override
  String get susceptible => 'Susceptible';

  @override
  String get intermediate => 'Intermediate';

  @override
  String get resistant => 'Resistant';

  @override
  String get insufficientEvidence => 'IE';

  @override
  String get growth => 'Growth';

  @override
  String get inhibition => 'Inhibition';

  @override
  String get partial => 'Partial';

  @override
  String get uncertain => 'Uncertain';

  @override
  String get tapToEdit => 'Tap well to edit';

  @override
  String get editWells => 'Edit Wells';

  @override
  String get changeColor => 'Change to:';

  @override
  String get recalculateMic => 'Recalculate MIC';

  @override
  String get done => 'Done';

  @override
  String get save => 'Save';

  @override
  String get share => 'Share';

  @override
  String get export => 'Export';

  @override
  String get delete => 'Delete';

  @override
  String get shareResults => 'Share Results';

  @override
  String get exportFormat => 'Export Format';

  @override
  String get pdfReport => 'PDF Report';

  @override
  String get pdfReportDesc => 'Full report with plate image and all results';

  @override
  String get imageSummary => 'Image + Summary';

  @override
  String get imageSummaryDesc => 'Annotated plate image with text summary';

  @override
  String get textOnly => 'Text Only';

  @override
  String get textOnlyDesc => 'Plain text results for quick sharing';

  @override
  String get includeInExport => 'Include in export:';

  @override
  String get analystName => 'Analyst name';

  @override
  String get timestamp => 'Timestamp';

  @override
  String get rawConfidence => 'Raw confidence values';

  @override
  String get shareVia => 'Share via...';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get profile => 'Profile';

  @override
  String get editProfile => 'Edit Profile';

  @override
  String get defaultOrganism => 'Default Organism';

  @override
  String get language => 'Language';

  @override
  String get about => 'About';

  @override
  String get version => 'Version';

  @override
  String get disclaimer =>
      'Results are for guidance only. Manual verification is recommended.';

  @override
  String get controlWellWarning =>
      'Control well (K) should show growth (pink). If not, repeat the test.';

  @override
  String get positiveControl => 'Positive Control (K)';

  @override
  String get error => 'Error';

  @override
  String get retry => 'Retry';

  @override
  String get cancel => 'Cancel';

  @override
  String get ok => 'OK';

  @override
  String get confirm => 'Confirm';

  @override
  String get deleteConfirm => 'Are you sure you want to delete this analysis?';

  @override
  String get cameraPermissionDenied =>
      'Camera permission is required to capture plates';

  @override
  String get storagePermissionDenied =>
      'Storage permission is required to save results';

  @override
  String get grantPermission => 'Grant Permission';
}
