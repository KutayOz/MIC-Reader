import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_tr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('tr'),
  ];

  /// The application title
  ///
  /// In en, this message translates to:
  /// **'MIC Reader'**
  String get appTitle;

  /// No description provided for @welcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get welcome;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back, {name}'**
  String welcomeBack(String name);

  /// No description provided for @onboardingTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to MIC Reader'**
  String get onboardingTitle;

  /// No description provided for @onboardingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Antifungal susceptibility testing made easy'**
  String get onboardingSubtitle;

  /// No description provided for @enterYourName.
  ///
  /// In en, this message translates to:
  /// **'Enter your name'**
  String get enterYourName;

  /// No description provided for @nameHint.
  ///
  /// In en, this message translates to:
  /// **'Dr. Name Surname'**
  String get nameHint;

  /// No description provided for @institution.
  ///
  /// In en, this message translates to:
  /// **'Institution (optional)'**
  String get institution;

  /// No description provided for @institutionHint.
  ///
  /// In en, this message translates to:
  /// **'Hospital/Laboratory name'**
  String get institutionHint;

  /// No description provided for @selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select language'**
  String get selectLanguage;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get getStarted;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @capture.
  ///
  /// In en, this message translates to:
  /// **'Capture'**
  String get capture;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @newAnalysis.
  ///
  /// In en, this message translates to:
  /// **'New Analysis'**
  String get newAnalysis;

  /// No description provided for @recentResults.
  ///
  /// In en, this message translates to:
  /// **'Recent Results'**
  String get recentResults;

  /// No description provided for @viewAllHistory.
  ///
  /// In en, this message translates to:
  /// **'View All History'**
  String get viewAllHistory;

  /// No description provided for @noRecentResults.
  ///
  /// In en, this message translates to:
  /// **'No recent results'**
  String get noRecentResults;

  /// No description provided for @capturePlate.
  ///
  /// In en, this message translates to:
  /// **'Capture Plate'**
  String get capturePlate;

  /// No description provided for @flashOn.
  ///
  /// In en, this message translates to:
  /// **'Flash On'**
  String get flashOn;

  /// No description provided for @flashOff.
  ///
  /// In en, this message translates to:
  /// **'Flash Off'**
  String get flashOff;

  /// No description provided for @captureHint.
  ///
  /// In en, this message translates to:
  /// **'Align the plate within the guide and tap capture'**
  String get captureHint;

  /// No description provided for @flashWarning.
  ///
  /// In en, this message translates to:
  /// **'Keep flash ON for best results'**
  String get flashWarning;

  /// No description provided for @analyzing.
  ///
  /// In en, this message translates to:
  /// **'Analyzing...'**
  String get analyzing;

  /// No description provided for @analysisResults.
  ///
  /// In en, this message translates to:
  /// **'Analysis Results'**
  String get analysisResults;

  /// No description provided for @selectOrganism.
  ///
  /// In en, this message translates to:
  /// **'Select Organism'**
  String get selectOrganism;

  /// No description provided for @micResults.
  ///
  /// In en, this message translates to:
  /// **'MIC Results'**
  String get micResults;

  /// No description provided for @drug.
  ///
  /// In en, this message translates to:
  /// **'Drug'**
  String get drug;

  /// No description provided for @micValue.
  ///
  /// In en, this message translates to:
  /// **'MIC (mg/L)'**
  String get micValue;

  /// No description provided for @interpretation.
  ///
  /// In en, this message translates to:
  /// **'Interpretation'**
  String get interpretation;

  /// No description provided for @susceptible.
  ///
  /// In en, this message translates to:
  /// **'Susceptible'**
  String get susceptible;

  /// No description provided for @intermediate.
  ///
  /// In en, this message translates to:
  /// **'Intermediate'**
  String get intermediate;

  /// No description provided for @resistant.
  ///
  /// In en, this message translates to:
  /// **'Resistant'**
  String get resistant;

  /// No description provided for @insufficientEvidence.
  ///
  /// In en, this message translates to:
  /// **'IE'**
  String get insufficientEvidence;

  /// No description provided for @growth.
  ///
  /// In en, this message translates to:
  /// **'Growth'**
  String get growth;

  /// No description provided for @inhibition.
  ///
  /// In en, this message translates to:
  /// **'Inhibition'**
  String get inhibition;

  /// No description provided for @partial.
  ///
  /// In en, this message translates to:
  /// **'Partial'**
  String get partial;

  /// No description provided for @uncertain.
  ///
  /// In en, this message translates to:
  /// **'Uncertain'**
  String get uncertain;

  /// No description provided for @tapToEdit.
  ///
  /// In en, this message translates to:
  /// **'Tap well to edit'**
  String get tapToEdit;

  /// No description provided for @editWells.
  ///
  /// In en, this message translates to:
  /// **'Edit Wells'**
  String get editWells;

  /// No description provided for @changeColor.
  ///
  /// In en, this message translates to:
  /// **'Change to:'**
  String get changeColor;

  /// No description provided for @recalculateMic.
  ///
  /// In en, this message translates to:
  /// **'Recalculate MIC'**
  String get recalculateMic;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @export.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get export;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @shareResults.
  ///
  /// In en, this message translates to:
  /// **'Share Results'**
  String get shareResults;

  /// No description provided for @exportFormat.
  ///
  /// In en, this message translates to:
  /// **'Export Format'**
  String get exportFormat;

  /// No description provided for @pdfReport.
  ///
  /// In en, this message translates to:
  /// **'PDF Report'**
  String get pdfReport;

  /// No description provided for @pdfReportDesc.
  ///
  /// In en, this message translates to:
  /// **'Full report with plate image and all results'**
  String get pdfReportDesc;

  /// No description provided for @imageSummary.
  ///
  /// In en, this message translates to:
  /// **'Image + Summary'**
  String get imageSummary;

  /// No description provided for @imageSummaryDesc.
  ///
  /// In en, this message translates to:
  /// **'Annotated plate image with text summary'**
  String get imageSummaryDesc;

  /// No description provided for @textOnly.
  ///
  /// In en, this message translates to:
  /// **'Text Only'**
  String get textOnly;

  /// No description provided for @textOnlyDesc.
  ///
  /// In en, this message translates to:
  /// **'Plain text results for quick sharing'**
  String get textOnlyDesc;

  /// No description provided for @includeInExport.
  ///
  /// In en, this message translates to:
  /// **'Include in export:'**
  String get includeInExport;

  /// No description provided for @analystName.
  ///
  /// In en, this message translates to:
  /// **'Analyst name'**
  String get analystName;

  /// No description provided for @timestamp.
  ///
  /// In en, this message translates to:
  /// **'Timestamp'**
  String get timestamp;

  /// No description provided for @rawConfidence.
  ///
  /// In en, this message translates to:
  /// **'Raw confidence values'**
  String get rawConfidence;

  /// No description provided for @shareVia.
  ///
  /// In en, this message translates to:
  /// **'Share via...'**
  String get shareVia;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfile;

  /// No description provided for @defaultOrganism.
  ///
  /// In en, this message translates to:
  /// **'Default Organism'**
  String get defaultOrganism;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @disclaimer.
  ///
  /// In en, this message translates to:
  /// **'Results are for guidance only. Manual verification is recommended.'**
  String get disclaimer;

  /// No description provided for @controlWellWarning.
  ///
  /// In en, this message translates to:
  /// **'Control well (K) should show growth (pink). If not, repeat the test.'**
  String get controlWellWarning;

  /// No description provided for @positiveControl.
  ///
  /// In en, this message translates to:
  /// **'Positive Control (K)'**
  String get positiveControl;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @deleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this analysis?'**
  String get deleteConfirm;

  /// No description provided for @cameraPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Camera permission is required to capture plates'**
  String get cameraPermissionDenied;

  /// No description provided for @storagePermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Storage permission is required to save results'**
  String get storagePermissionDenied;

  /// No description provided for @grantPermission.
  ///
  /// In en, this message translates to:
  /// **'Grant Permission'**
  String get grantPermission;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'tr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'tr':
      return AppLocalizationsTr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
