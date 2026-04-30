import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/language_provider.dart';
import '../services/connectivity_service.dart';
import '../theme.dart';

class RuraxTopBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showBack;
  final VoidCallback? onBack;
  /// Optional mic button: supply a callback to show the mic icon in the top bar.
  /// Used by diagnosis screens that implement voice input.
  final VoidCallback? onMicTap;
  final bool micActive;

  const RuraxTopBar({
    super.key,
    this.title = 'SenseAI',
    this.showBack = false,
    this.onBack,
    this.onMicTap,
    this.micActive = false,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 32);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _TopBar(
          title: title,
          showBack: showBack,
          onBack: onBack,
          onMicTap: onMicTap,
          micActive: micActive,
        ),
        const _StatusBar(),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  final String title;
  final bool showBack;
  final VoidCallback? onBack;
  final VoidCallback? onMicTap;
  final bool micActive;

  const _TopBar({
    required this.title,
    required this.showBack,
    this.onBack,
    this.onMicTap,
    this.micActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.darkGreen,
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: MediaQuery.of(context).padding.top + 8,
        bottom: 10,
      ),
      child: Row(
        children: [
          if (showBack)
            GestureDetector(
              onTap: onBack ?? () => Navigator.of(context).pop(),
              child: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 18),
            ),
          if (showBack) const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const Spacer(),
          // Mic button — shown when onMicTap is provided
          if (onMicTap != null) ...[
            GestureDetector(
              onTap: onMicTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: micActive ? Colors.white : Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: micActive ? Colors.white : Colors.white38,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      micActive ? Icons.mic : Icons.mic_none,
                      color: micActive ? AppColors.darkGreen : Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      micActive ? 'Stop' : 'Voice',
                      style: TextStyle(
                        color: micActive ? AppColors.darkGreen : Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          _LanguageButton(),
          const SizedBox(width: 10),
          if (!showBack)
            const Icon(Icons.logout, color: Colors.white, size: 20),
        ],
      ),
    );
  }
}

class _LanguageButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, lang, _) => GestureDetector(
        onTap: () => _showLanguagePicker(context, lang),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white38),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.language, color: Colors.white, size: 14),
              const SizedBox(width: 4),
              Text(
                lang.currentLanguageName,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLanguagePicker(BuildContext context, LanguageProvider lang) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Language',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: LanguageProvider.supportedLanguages.entries.map((e) {
                final selected = lang.locale.languageCode == e.key;
                return GestureDetector(
                  onTap: () {
                    lang.setLocale(e.key);
                    Navigator.pop(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.darkGreen : AppColors.cardWhite,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                          color: selected ? AppColors.darkGreen : AppColors.divider),
                    ),
                    child: Text(
                      e.value,
                      style: TextStyle(
                        color: selected ? Colors.white : AppColors.textDark,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                        fontSize: 14,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar();

  @override
  Widget build(BuildContext context) {
    final svc = ConnectivityService();
    return StreamBuilder<SyncStatus>(
      stream: svc.statusStream,
      initialData: svc.status,
      builder: (_, snap) {
        final online = svc.isOnline;
        final status = snap.data ?? SyncStatus.idle;
        String rightLabel = 'SYNCED';
        Color rightColor = Colors.lightGreenAccent;

        if (status == SyncStatus.syncing) {
          rightLabel = 'SYNCING...';
          rightColor = Colors.yellowAccent;
        } else if (status == SyncStatus.error) {
          rightLabel = 'SYNC ERROR';
          rightColor = Colors.redAccent;
        } else if (!online) {
          rightLabel = 'OFFLINE';
          rightColor = Colors.orangeAccent;
        }

        return Container(
          color: AppColors.statusGreen,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          child: Row(
            children: [
              const Icon(Icons.person_outline, color: Colors.white70, size: 14),
              const SizedBox(width: 4),
              const Text('HEALTH WORKER',
                  style: TextStyle(color: Colors.white, fontSize: 11, letterSpacing: 1)),
              const Spacer(),
              Icon(
                online ? Icons.wifi : Icons.wifi_off,
                color: online ? Colors.lightGreenAccent : Colors.orangeAccent,
                size: 12,
              ),
              const SizedBox(width: 4),
              Text(
                online ? 'ONLINE' : 'OFFLINE',
                style: TextStyle(
                    color: online ? Colors.lightGreenAccent : Colors.orangeAccent,
                    fontSize: 11,
                    letterSpacing: 0.8),
              ),
              const SizedBox(width: 16),
              Icon(Icons.sync, color: rightColor, size: 12),
              const SizedBox(width: 4),
              Text(rightLabel,
                  style: TextStyle(color: rightColor, fontSize: 11, letterSpacing: 0.8)),
            ],
          ),
        );
      },
    );
  }
}