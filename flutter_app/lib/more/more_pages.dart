import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/l10n/app_language.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/widgets/async_view.dart';
import '../features/dashboard/dashboard_page.dart' show recsProvider;

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    final recs = ref.watch(recsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(tr(lang, 'notifications'))),
      body: AsyncView<List<dynamic>>(
        value: recs,
        onRetry: () => ref.invalidate(recsProvider),
        builder: (list) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(recsProvider),
          child: list.isEmpty
              ? ListView(children: [
                  SizedBox(
                      height: 240,
                      child: EmptyState(tr(lang, 'no_notifications')))
                ])
              : ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final r = list[i] as Map<String, dynamic>;
                    final anomaly = '${r['kind']}' == 'ANOMALY';
                    return ListTile(
                      leading: Icon(
                        anomaly
                            ? Icons.warning_amber
                            : Icons.notifications_none,
                        color: anomaly ? Colors.orange : null,
                      ),
                      title: Text('${r['message']}'),
                      subtitle: Text('${r['created_at']}'),
                      isThreeLine: false,
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    final mode = ref.watch(themeModeProvider);
    return Scaffold(
      appBar: AppBar(title: Text(tr(lang, 'settings'))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(tr(lang, 'theme'), style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        SegmentedButton<ThemeMode>(
          segments: [
            ButtonSegment(
                value: ThemeMode.light,
                icon: const Icon(Icons.light_mode_outlined),
                label: Text(tr(lang, 'light'))),
            ButtonSegment(
                value: ThemeMode.dark,
                icon: const Icon(Icons.dark_mode_outlined),
                label: Text(tr(lang, 'dark'))),
            ButtonSegment(
                value: ThemeMode.system,
                icon: const Icon(Icons.settings_suggest_outlined),
                label: Text(tr(lang, 'system'))),
          ],
          selected: {mode},
          onSelectionChanged: (s) =>
              ref.read(themeModeProvider.notifier).set(s.first),
        ),
      ]),
    );
  }
}
