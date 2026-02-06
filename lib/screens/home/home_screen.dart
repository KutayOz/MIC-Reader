import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../data/models/models.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../providers/history_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/native_opencv.dart';
import '../analysis/analysis_screen.dart';
import '../camera/camera_screen.dart';
import '../history/history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final TextEditingController _patientNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Load recent analyses
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HistoryProvider>().loadRecent();
    });
  }

  @override
  void dispose() {
    _patientNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final userProvider = context.watch<UserProvider>();

    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: [
            _HomeTab(
              userName: userProvider.name,
              institution: userProvider.institution,
              patientNameController: _patientNameController,
              onViewHistory: () => setState(() => _currentIndex = 1),
            ),
            const HistoryScreen(),
            const _SettingsTab(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: l10n.home,
          ),
          NavigationDestination(
            icon: const Icon(Icons.history_outlined),
            selectedIcon: const Icon(Icons.history),
            label: l10n.history,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: l10n.settings,
          ),
        ],
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  final String? userName;
  final String? institution;
  final TextEditingController patientNameController;
  final VoidCallback onViewHistory;

  const _HomeTab({
    this.userName,
    this.institution,
    required this.patientNameController,
    required this.onViewHistory,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            userName != null ? l10n.welcomeBack(userName!) : l10n.welcome,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          if (institution != null) ...[
            const SizedBox(height: 4),
            Text(
              institution!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
          const SizedBox(height: 24),

          // Patient Name Input
          TextField(
            controller: patientNameController,
            decoration: InputDecoration(
              labelText: l10n.patientName,
              hintText: l10n.patientNameHint,
              prefixIcon: const Icon(Icons.person_outline),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(height: 16),

          // New Analysis Card
          GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CameraScreen(
                    patientName: patientNameController.text.trim().isEmpty
                        ? null
                        : patientNameController.text.trim(),
                  ),
                ),
              );
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.camera_alt_outlined,
                    size: 48,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.newAnalysis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Recent Results header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.recentResults,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              TextButton(
                onPressed: onViewHistory,
                child: Text(l10n.viewAllHistory),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Recent Results list
          Expanded(
            child: Consumer<HistoryProvider>(
              builder: (context, provider, child) {
                if (provider.recentAnalyses.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.science_outlined,
                          size: 64,
                          color: AppColors.textSecondary.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l10n.noRecentResults,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: provider.recentAnalyses.length,
                  itemBuilder: (context, index) {
                    final analysis = provider.recentAnalyses[index];
                    return _RecentResultCard(
                      analysis: analysis,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => AnalysisScreen(
                              imagePath: analysis.imagePath,
                              existingAnalysis: analysis,
                              patientName: analysis.notes,
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentResultCard extends StatelessWidget {
  final PlateAnalysis analysis;
  final VoidCallback onTap;

  const _RecentResultCard({
    required this.analysis,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM, HH:mm');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 48,
            height: 48,
            child: _buildThumbnail(),
          ),
        ),
        title: Text(
          analysis.organism ?? 'Unknown',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          dateFormat.format(analysis.timestamp),
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _MiniStat(color: AppColors.growth, count: analysis.growthCount),
            const SizedBox(width: 4),
            _MiniStat(color: AppColors.inhibition, count: analysis.inhibitionCount),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    final file = File(analysis.imagePath);

    return FutureBuilder<bool>(
      future: file.exists(),
      builder: (context, snapshot) {
        if (snapshot.data == true) {
          return Image.file(
            file,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _placeholder(),
          );
        }
        return _placeholder();
      },
    );
  }

  Widget _placeholder() {
    return Container(
      color: AppColors.background,
      child: const Icon(Icons.science_outlined, color: AppColors.textSecondary),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final Color color;
  final int count;

  const _MiniStat({required this.color, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}


class _SettingsTab extends StatelessWidget {
  const _SettingsTab();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final userProvider = context.watch<UserProvider>();
    final localeProvider = context.watch<LocaleProvider>();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.settingsTitle,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 24),
          _SettingsTile(
            icon: Icons.person_outline,
            title: l10n.profile,
            subtitle: userProvider.name ?? l10n.editProfile,
            onTap: () => _showEditProfileDialog(context),
          ),
          // Auto-save toggle
          SwitchListTile(
            secondary: const Icon(Icons.save_outlined, color: AppColors.primary),
            title: Text(l10n.autoSave),
            subtitle: Text(l10n.autoSaveDescription),
            value: userProvider.autoSaveEnabled,
            onChanged: (value) => userProvider.setAutoSaveEnabled(value),
            contentPadding: EdgeInsets.zero,
          ),
          _SettingsTile(
            icon: Icons.language_outlined,
            title: l10n.language,
            subtitle: localeProvider.locale.languageCode == 'tr' ? 'Türkçe' : 'English',
            onTap: () => _showLanguageDialog(context),
          ),
          _SettingsTile(
            icon: Icons.info_outline,
            title: l10n.about,
            subtitle: '${l10n.version} 1.0.0',
            onTap: () => _showAboutDialog(context),
          ),
          const Divider(),
          _SettingsTile(
            icon: Icons.bug_report_outlined,
            title: 'Debug Info',
            subtitle: NativeOpenCV.isAvailable ? 'OpenCV: Active' : 'OpenCV: Fallback mode',
            onTap: () => _showDebugDialog(context),
          ),
        ],
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final userProvider = context.read<UserProvider>();
    final nameController = TextEditingController(text: userProvider.name ?? '');
    final institutionController = TextEditingController(text: userProvider.institution ?? '');

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.editProfile),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: l10n.enterYourName,
                hintText: l10n.nameHint,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: institutionController,
              decoration: InputDecoration(
                labelText: l10n.institution,
                hintText: l10n.institutionHint,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                userProvider.setUser(
                  name: nameController.text.trim(),
                  institution: institutionController.text.trim().isEmpty
                      ? null
                      : institutionController.text.trim(),
                );
              }
              Navigator.pop(dialogContext);
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }

  void _showLanguageDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final localeProvider = context.read<LocaleProvider>();
    final currentLanguage = localeProvider.locale.languageCode;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.selectLanguage),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('English'),
              leading: Icon(
                currentLanguage == 'en' ? Icons.radio_button_checked : Icons.radio_button_off,
                color: currentLanguage == 'en' ? AppColors.primary : AppColors.textSecondary,
              ),
              onTap: () {
                localeProvider.setLocaleFromCode('en');
                Navigator.pop(dialogContext);
              },
            ),
            ListTile(
              title: const Text('Türkçe'),
              leading: Icon(
                currentLanguage == 'tr' ? Icons.radio_button_checked : Icons.radio_button_off,
                color: currentLanguage == 'tr' ? AppColors.primary : AppColors.textSecondary,
              ),
              onTap: () {
                localeProvider.setLocaleFromCode('tr');
                Navigator.pop(dialogContext);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.about),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.appTitle,
              style: Theme.of(dialogContext).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text('${l10n.version} 1.0.0'),
            const SizedBox(height: 16),
            Text(
              'MIC YST Plate Reader for antifungal susceptibility testing.',
              style: Theme.of(dialogContext).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.disclaimer,
              style: Theme.of(dialogContext).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.ok),
          ),
        ],
      ),
    );
  }

  void _showDebugDialog(BuildContext context) {
    final isAvailable = NativeOpenCV.isAvailable;
    final error = NativeOpenCV.initializationError;
    String? version;

    if (isAvailable) {
      try {
        version = NativeOpenCV.instance.getVersion();
      } catch (e) {
        version = 'Error: $e';
      }
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.bug_report, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Debug Info'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DebugRow(
              label: 'OpenCV Status',
              value: isAvailable ? '✅ Active' : '❌ Not Available',
              valueColor: isAvailable ? Colors.green : Colors.red,
            ),
            if (isAvailable && version != null)
              _DebugRow(label: 'OpenCV Version', value: version),
            if (!isAvailable && error != null)
              _DebugRow(
                label: 'Error',
                value: error,
                valueColor: Colors.red,
              ),
            const Divider(),
            _DebugRow(
              label: 'Detection Method',
              value: isAvailable ? 'HoughCircles (Native)' : 'Blob Detection (Fallback)',
            ),
            _DebugRow(
              label: 'Expected Accuracy',
              value: isAvailable ? '~96/96 wells' : '~72/96 wells',
            ),
            const Divider(),
            _DebugRow(label: 'Platform', value: Platform.operatingSystem),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _DebugRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _DebugRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }
}
