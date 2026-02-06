// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get appTitle => 'MIC Okuyucu';

  @override
  String get welcome => 'Hoş Geldiniz';

  @override
  String welcomeBack(String name) {
    return 'Tekrar hoş geldiniz, $name';
  }

  @override
  String get onboardingTitle => 'MIC Okuyucu\'ya Hoş Geldiniz';

  @override
  String get onboardingSubtitle =>
      'Antifungal duyarlılık testi artık çok kolay';

  @override
  String get enterYourName => 'Adınızı girin';

  @override
  String get nameHint => 'Dr. Ad Soyad';

  @override
  String get institution => 'Kurum (isteğe bağlı)';

  @override
  String get institutionHint => 'Hastane/Laboratuvar adı';

  @override
  String get selectLanguage => 'Dil seçin';

  @override
  String get getStarted => 'Başla';

  @override
  String get home => 'Ana Sayfa';

  @override
  String get capture => 'Çekim';

  @override
  String get history => 'Geçmiş';

  @override
  String get settings => 'Ayarlar';

  @override
  String get newAnalysis => 'Yeni Analiz';

  @override
  String get recentResults => 'Son Sonuçlar';

  @override
  String get viewAllHistory => 'Tüm Geçmişi Gör';

  @override
  String get noRecentResults => 'Henüz sonuç yok';

  @override
  String get capturePlate => 'Plak Çekimi';

  @override
  String get flashOn => 'Flaş Açık';

  @override
  String get flashOff => 'Flaş Kapalı';

  @override
  String get captureHint => 'Plakı kılavuz içine hizalayın ve çekin';

  @override
  String get flashWarning => 'En iyi sonuç için flaşı AÇIK tutun';

  @override
  String get rotatePhone => 'Telefonunuzu yatay çevirin';

  @override
  String get rotatePhoneHint => 'Plağı çekmek için telefonunuzu yatay tutun';

  @override
  String get fromGallery => 'Galeriden';

  @override
  String get fromCamera => 'Kameradan';

  @override
  String get chooseSource => 'Görüntü Kaynağı Seçin';

  @override
  String get alignPlateHint => 'Plağı çerçeveye sığdırın';

  @override
  String get analyzing => 'Analiz ediliyor...';

  @override
  String get analysisResults => 'Analiz Sonuçları';

  @override
  String get selectOrganism => 'Organizma Seçin';

  @override
  String get micResults => 'MIC Sonuçları';

  @override
  String get drug => 'İlaç';

  @override
  String get micValue => 'MIC (mg/L)';

  @override
  String get interpretation => 'Yorum';

  @override
  String get susceptible => 'Duyarlı';

  @override
  String get intermediate => 'Orta Duyarlı';

  @override
  String get resistant => 'Dirençli';

  @override
  String get insufficientEvidence => 'YK';

  @override
  String get growth => 'Üreme';

  @override
  String get inhibition => 'İnhibisyon';

  @override
  String get partial => 'Kısmi';

  @override
  String get uncertain => 'Belirsiz';

  @override
  String get needsReview => 'İnceleme Gerekli';

  @override
  String get manuallyEdited => 'Düzenlendi';

  @override
  String get tapToEdit => 'Düzenlemek için kuyucuğa dokunun';

  @override
  String get editWells => 'Kuyucukları Düzenle';

  @override
  String get changeColor => 'Değiştir:';

  @override
  String get recalculateMic => 'MIC\'i Yeniden Hesapla';

  @override
  String get done => 'Tamam';

  @override
  String get save => 'Kaydet';

  @override
  String get share => 'Paylaş';

  @override
  String get export => 'Dışa Aktar';

  @override
  String get delete => 'Sil';

  @override
  String get shareResults => 'Sonuçları Paylaş';

  @override
  String get exportFormat => 'Dışa Aktarma Formatı';

  @override
  String get pdfReport => 'PDF Raporu';

  @override
  String get pdfReportDesc => 'Plak görüntüsü ve tüm sonuçlarla tam rapor';

  @override
  String get imageSummary => 'Görüntü + Özet';

  @override
  String get imageSummaryDesc => 'Metin özetiyle açıklamalı plak görüntüsü';

  @override
  String get textOnly => 'Yalnızca Metin';

  @override
  String get textOnlyDesc => 'Hızlı paylaşım için düz metin sonuçları';

  @override
  String get includeInExport => 'Dışa aktarmaya dahil et:';

  @override
  String get analystName => 'Analist adı';

  @override
  String get timestamp => 'Zaman damgası';

  @override
  String get rawConfidence => 'Ham güven değerleri';

  @override
  String get shareVia => 'Şununla paylaş...';

  @override
  String get settingsTitle => 'Ayarlar';

  @override
  String get profile => 'Profil';

  @override
  String get editProfile => 'Profili Düzenle';

  @override
  String get defaultOrganism => 'Varsayılan Organizma';

  @override
  String get language => 'Dil';

  @override
  String get about => 'Hakkında';

  @override
  String get version => 'Sürüm';

  @override
  String get disclaimer =>
      'Sonuçlar yalnızca rehber niteliğindedir. Manuel doğrulama önerilir.';

  @override
  String get controlWellWarning =>
      'Kontrol kuyucuğu (K) üreme (pembe) göstermelidir. Göstermiyorsa testi tekrarlayın.';

  @override
  String get positiveControl => 'Pozitif Kontrol (K)';

  @override
  String get error => 'Hata';

  @override
  String get retry => 'Tekrar Dene';

  @override
  String get cancel => 'İptal';

  @override
  String get ok => 'Tamam';

  @override
  String get confirm => 'Onayla';

  @override
  String get deleteConfirm => 'Bu analizi silmek istediğinizden emin misiniz?';

  @override
  String get cameraPermissionDenied =>
      'Plak çekimi için kamera izni gereklidir';

  @override
  String get storagePermissionDenied =>
      'Sonuçları kaydetmek için depolama izni gereklidir';

  @override
  String get grantPermission => 'İzin Ver';

  @override
  String get autoSave => 'Otomatik kaydet';

  @override
  String get autoSaveDescription =>
      'Analiz sonuçlarını işlem sonrası otomatik kaydet';

  @override
  String get analysisSavedAuto => 'Analiz otomatik kaydedildi';

  @override
  String get patientName => 'Hasta Adı';

  @override
  String get patientNameHint => 'Hasta adını girin (opsiyonel)';

  @override
  String get editPatientName => 'Hasta Adını Düzenle';
}
