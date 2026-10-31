import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const Map<String, Map<String, String>> _strings = {
  'en': {
    'dashboard': 'Dashboard',
    'transactions': 'Transactions',
    'budgets': 'Budgets',
    'goals_debts': 'Goals & Debts',
    'invest': 'Invest',
    'ai_assistant': 'AI Assistant',
    'admin_logs': 'Admin: Audit Logs',
    'home': 'Home',
    'txns': 'Txns',
    'budget': 'Budget',
    'goals': 'Goals',
    'ai': 'AI',
    'admin': 'Admin',
    'more_menu': 'More Menu',
    'notifications': 'Notifications',
    'my_profile': 'My Profile',
    'settings': 'Settings',
    'language': 'Language (Khmer / English)',
    'choose_language': 'Choose language',
    'logout': 'Logout',
    'theme': 'Theme',
    'light': 'Light',
    'dark': 'Dark',
    'system': 'System',
    'no_notifications': 'No notifications yet.',
  },
  'km': {
    'dashboard': 'ផ្ទាំងគ្រប់គ្រង',
    'transactions': 'ប្រតិបត្តិការ',
    'budgets': 'ថវិកា',
    'goals_debts': 'គោលដៅ និងបំណុល',
    'invest': 'វិនិយោគ',
    'ai_assistant': 'ជំនួយការ AI',
    'admin_logs': 'អ្នកគ្រប់គ្រង៖ កំណត់ហេតុ',
    'home': 'ទំព័រដើម',
    'txns': 'ប្រតិបត្តិការ',
    'budget': 'ថវិកា',
    'goals': 'គោលដៅ',
    'ai': 'AI',
    'admin': 'អ្នកគ្រប់គ្រង',
    'more_menu': 'ម៉ឺនុយបន្ថែម',
    'notifications': 'ការជូនដំណឹង',
    'my_profile': 'ប្រវត្តិរូបរបស់ខ្ញុំ',
    'settings': 'ការកំណត់',
    'language': 'ភាសា (ខ្មែរ / English)',
    'choose_language': 'ជ្រើសរើសភាសា',
    'logout': 'ចាកចេញ',
    'theme': 'រចនាបថ',
    'light': 'ភ្លឺ',
    'dark': 'ងងឹត',
    'system': 'តាមប្រព័ន្ធ',
    'no_notifications': 'មិនមានការជូនដំណឹងទេ។',
  },
};

String tr(String lang, String key) =>
    _strings[lang]?[key] ?? _strings['en']![key] ?? key;

final languageProvider = StateNotifierProvider<LanguageController, String>(
    (ref) => LanguageController());

class LanguageController extends StateNotifier<String> {
  LanguageController() : super('en') {
    _load();
  }

  final FlutterSecureStorage _s = const FlutterSecureStorage();
  static const _key = 'language';

  Future<void> _load() async {
    final v = await _s.read(key: _key);
    if (!mounted) {
      return;
    }
    if (v == 'km' || v == 'en') {
      state = v!;
    }
  }

  Future<void> set(String lang) async {
    state = lang;
    await _s.write(key: _key, value: lang);
  }
}
