import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/network/api_client.dart';
import '../../core/widgets/async_view.dart';
import '../admin/admin_page.dart' show meProvider;
import '../auth/auth_controller.dart';
import '../transactions/transactions_page.dart' show accountsProvider;
import 'profile_image.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  void _choose(BuildContext context, WidgetRef ref, int uid, bool hasImage) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from gallery'),
            onTap: () {
              Navigator.pop(ctx);
              _pick(context, ref, uid, ImageSource.gallery);
            },
          ),
          if (!kIsWeb)
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(ctx);
                _pick(context, ref, uid, ImageSource.camera);
              },
            ),
          if (hasImage)
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Remove photo'),
              onTap: () {
                Navigator.pop(ctx);
                ref.read(avatarProvider(uid).notifier).remove();
              },
            ),
        ]),
      ),
    );
  }

  Future<void> _pick(
      BuildContext context, WidgetRef ref, int uid, ImageSource source) async {
    try {
      await ref.read(avatarProvider(uid).notifier).pick(source);
    } catch (e) {
      if (context.mounted) showSnack(context, 'Could not load the image');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(meProvider);
    final accounts = ref.watch(accountsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: AsyncView<Map<String, dynamic>>(
        value: me,
        onRetry: () => ref.invalidate(meProvider),
        builder: (u) {
          final uid = (u['id'] as num).toInt();
          final avatar = ref.watch(avatarProvider(uid));
          final name = '${u['full_name']}';
          final initial = name.isEmpty ? '?' : name[0].toUpperCase();
          return ListView(padding: const EdgeInsets.all(16), children: [
            Center(
              child: Column(children: [
                GestureDetector(
                  onTap: () => _choose(context, ref, uid, avatar != null),
                  child: Stack(children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundImage:
                          avatar != null ? MemoryImage(avatar) : null,
                      child: avatar == null
                          ? Text(initial, style: const TextStyle(fontSize: 36))
                          : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        child: Icon(Icons.edit,
                            size: 16,
                            color: Theme.of(context).colorScheme.onPrimary),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 12),
                Text(name, style: Theme.of(context).textTheme.titleLarge),
                Text('${u['email']}'),
                const SizedBox(height: 8),
                Wrap(spacing: 8, children: [
                  Chip(label: Text('${u['role']}')),
                  Chip(label: Text('${u['currency']}')),
                ]),
              ]),
            ),
            const SizedBox(height: 16),
            Text('Accounts', style: Theme.of(context).textTheme.titleMedium),
            accounts.when(
              loading: () => const Padding(
                  padding: EdgeInsets.all(16),
                  child: LinearProgressIndicator()),
              error: (e, _) => Text(errorMessage(e)),
              data: (list) {
                final total =
                    list.fold<double>(0, (s, a) => s + toD(a['balance']));
                return Column(children: [
                  for (final a in list)
                    Card(
                      child: ListTile(
                        leading:
                            const Icon(Icons.account_balance_wallet_outlined),
                        title: Text('${a['name']}'),
                        subtitle: Text('${a['type']}'),
                        trailing: Text(money(a['balance']),
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ListTile(
                    title: const Text('Total balance'),
                    trailing: Text(money(total),
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                ]);
              },
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
              onPressed: () {
                Navigator.of(context).pop();
                ref.read(authProvider.notifier).logout();
              },
            ),
          ]);
        },
      ),
    );
  }
}
