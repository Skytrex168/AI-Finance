import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/l10n/app_language.dart';
import '../admin/admin_page.dart';
import '../ai/chat_page.dart';
import '../auth/auth_controller.dart';
import '../budgets/budgets_page.dart';
import '../dashboard/dashboard_page.dart';
import '../goals/goals_page.dart';
import '../invest/invest_page.dart';
import '../../more/more_pages.dart';
import '../profile/profile_image.dart';
import '../profile/profile_page.dart';
import '../transactions/transactions_page.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});
  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _i = 0;

  void _push(Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  void _pickLanguage() {
    showDialog(
      context: context,
      builder: (ctx) => Consumer(builder: (ctx, ref, _) {
        final lang = ref.watch(languageProvider);
        return AlertDialog(
          title: Text(tr(lang, 'choose_language')),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              title: const Text('ខ្មែរ'),
              trailing: lang == 'km' ? const Icon(Icons.check) : null,
              onTap: () {
                ref.read(languageProvider.notifier).set('km');
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              title: const Text('English'),
              trailing: lang == 'en' ? const Icon(Icons.check) : null,
              onTap: () {
                ref.read(languageProvider.notifier).set('en');
                Navigator.pop(ctx);
              },
            ),
          ]),
        );
      }),
    );
  }

  void _openMore() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Consumer(builder: (ctx, ref, _) {
        final lang = ref.watch(languageProvider);
        return SafeArea(
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                  child: Text(tr(lang, 'more_menu'),
                      style: Theme.of(ctx).textTheme.titleLarge),
                ),
                ListTile(
                  leading: const Icon(Icons.notifications_none),
                  title: Text(tr(lang, 'notifications')),
                  onTap: () {
                    Navigator.pop(ctx);
                    _push(const NotificationsPage());
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(tr(lang, 'my_profile')),
                  onTap: () {
                    Navigator.pop(ctx);
                    _push(const ProfilePage());
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.settings_outlined),
                  title: Text(tr(lang, 'settings')),
                  onTap: () {
                    Navigator.pop(ctx);
                    _push(const SettingsPage());
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.translate),
                  title: Text(tr(lang, 'language')),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickLanguage();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: Text(tr(lang, 'logout')),
                  onTap: () {
                    Navigator.pop(ctx);
                    ref.read(authProvider.notifier).logout();
                  },
                ),
              ]),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    final me = ref.watch(meProvider).valueOrNull;
    final isAdmin = me != null && me['role'] == 'ADMIN';
    final uid = me == null ? null : (me['id'] as num).toInt();
    final avatar = uid == null ? null : ref.watch(avatarProvider(uid));

    final titles = [
      tr(lang, 'dashboard'),
      tr(lang, 'transactions'),
      tr(lang, 'budgets'),
      tr(lang, 'goals_debts'),
      tr(lang, 'invest'),
      tr(lang, 'ai_assistant'),
      if (isAdmin) tr(lang, 'admin_logs'),
    ];
    final pages = <Widget>[
      const DashboardPage(),
      const TransactionsPage(),
      const BudgetsPage(),
      const GoalsPage(),
      const InvestPage(),
      const ChatPage(),
      if (isAdmin) const AdminPage(),
    ];
    final index = _i < pages.length ? _i : 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[index]),
        actions: [
          if (isAdmin)
            const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Chip(label: Text('ADMIN'))),
          IconButton(
            tooltip: tr(lang, 'more_menu'),
            icon: avatar != null
                ? CircleAvatar(radius: 14, backgroundImage: MemoryImage(avatar))
                : const Icon(Icons.account_circle_outlined),
            onPressed: _openMore,
          ),
        ],
      ),
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (v) => setState(() => _i = v),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          NavigationDestination(
              icon: const Icon(Icons.dashboard_outlined),
              label: tr(lang, 'home')),
          NavigationDestination(
              icon: const Icon(Icons.receipt_long_outlined),
              label: tr(lang, 'txns')),
          NavigationDestination(
              icon: const Icon(Icons.pie_chart_outline),
              label: tr(lang, 'budget')),
          NavigationDestination(
              icon: const Icon(Icons.flag_outlined), label: tr(lang, 'goals')),
          NavigationDestination(
              icon: const Icon(Icons.trending_up), label: tr(lang, 'invest')),
          NavigationDestination(
              icon: const Icon(Icons.smart_toy_outlined),
              label: tr(lang, 'ai')),
          if (isAdmin)
            NavigationDestination(
                icon: const Icon(Icons.admin_panel_settings_outlined),
                label: tr(lang, 'admin')),
        ],
      ),
    );
  }
}
