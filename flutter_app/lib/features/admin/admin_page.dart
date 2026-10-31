import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/widgets/async_view.dart';
import '../auth/auth_controller.dart';

final meProvider =
    FutureProvider.autoDispose((ref) => ref.watch(apiProvider).me());
final auditProvider =
    FutureProvider.autoDispose((ref) => ref.watch(apiProvider).auditLogs());

class AdminPage extends ConsumerWidget {
  const AdminPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(auditProvider);
    return AsyncView<List<dynamic>>(
      value: logs,
      onRetry: () => ref.invalidate(auditProvider),
      builder: (list) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(auditProvider),
        child: list.isEmpty
            ? ListView(children: const [
                SizedBox(height: 200, child: EmptyState('No audit logs yet.'))
              ])
            : ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final l = list[i] as Map<String, dynamic>;
                  final failed = '${l['action']}'.contains('FAILED');
                  return ListTile(
                    dense: true,
                    leading: Icon(failed ? Icons.gpp_bad : Icons.history,
                        color: failed ? Colors.red : null),
                    title: Text('${l['action']}'),
                    subtitle: Text(
                        'user ${l['user_id'] ?? '-'}  |  ${l['detail'] ?? ''}\n${l['created_at']}'),
                    isThreeLine: true,
                  );
                },
              ),
      ),
    );
  }
}
