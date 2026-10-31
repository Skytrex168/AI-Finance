import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../../core/widgets/async_view.dart';
import '../auth/auth_controller.dart';
import '../transactions/transactions_page.dart';

final budgetsProvider =
    FutureProvider.autoDispose((ref) => ref.watch(apiProvider).budgets());

class BudgetsPage extends ConsumerWidget {
  const BudgetsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgets = ref.watch(budgetsProvider);
    return Scaffold(
      body: AsyncView<List<dynamic>>(
        value: budgets,
        onRetry: () => ref.invalidate(budgetsProvider),
        builder: (list) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(budgetsProvider),
          child: list.isEmpty
              ? ListView(children: const [
                  SizedBox(
                      height: 200,
                      child: EmptyState(
                          'No budgets for this month. Tap + to set one.'))
                ])
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final b = list[i] as Map<String, dynamic>;
                    final limit = toD(b['limit_amount']);
                    final spent = toD(b['spent']);
                    final ratio = limit == 0 ? 0.0 : (spent / limit);
                    final over = spent > limit;
                    return Card(
                      child: ListTile(
                        title: Text('${b['category']}'),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                LinearProgressIndicator(
                                    value: ratio.clamp(0.0, 1.0),
                                    color: over ? Colors.red : null),
                                const SizedBox(height: 4),
                                Text(
                                    '${money(spent)} of ${money(limit)}${over ? '  - over budget!' : ''}'),
                              ]),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            try {
                              await ref.read(apiProvider).deleteBudget(b['id']);
                              ref.invalidate(budgetsProvider);
                            } catch (e) {
                              if (context.mounted) {
                                showSnack(context, errorMessage(e));
                              }
                            }
                          },
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _add(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final cats = await ref.read(categoriesProvider.future);
    final expense = cats.where((c) => c['kind'] == 'EXPENSE').toList();
    int? cat = expense.isEmpty ? null : expense.first['id'] as int;
    final limit = TextEditingController();
    if (!context.mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Monthly budget'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<int>(
              initialValue: cat,
              items: [
                for (final c in expense)
                  DropdownMenuItem(
                      value: c['id'] as int, child: Text('${c['name']}'))
              ],
              onChanged: (v) => setS(() => cat = v),
            ),
            TextField(
              controller: limit,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration:
                  const InputDecoration(labelText: 'Limit', prefixText: '\$ '),
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final v = double.tryParse(limit.text);
                if (v == null || v <= 0 || cat == null) return;
                final now = DateTime.now();
                final month =
                    '${now.year}-${now.month.toString().padLeft(2, '0')}';
                try {
                  await ref.read(apiProvider).setBudget(cat!, month, v);
                  ref.invalidate(budgetsProvider);
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  if (ctx.mounted) showSnack(ctx, errorMessage(e));
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    limit.dispose();
  }
}
