import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/widgets/async_view.dart';
import '../auth/auth_controller.dart';

final summaryProvider = FutureProvider.autoDispose((ref) => ref.watch(apiProvider).summary());
final recsProvider = FutureProvider.autoDispose((ref) => ref.watch(apiProvider).recommendations());

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  static const _colors = [Colors.teal, Colors.orange, Colors.indigo, Colors.pink, Colors.green, Colors.brown, Colors.purple, Colors.blueGrey];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(summaryProvider);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(summaryProvider);
        ref.invalidate(recsProvider);
      },
      child: AsyncView<Map<String, dynamic>>(
        value: summary,
        onRetry: () => ref.invalidate(summaryProvider),
        builder: (s) {
          final cats = (s['byCategory'] as List).cast<Map<String, dynamic>>();
          final recs = ref.watch(recsProvider);
          return ListView(padding: const EdgeInsets.all(16), children: [
            Text('Month ${s['month']}', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(children: [
              _stat(context, 'Income', money(s['income']), Colors.green),
              _stat(context, 'Spent', money(s['expense']), Colors.red),
              _stat(context, 'Saved', money(s['savings']), Colors.teal),
            ]),
            Card(
              child: ListTile(
                leading: const Icon(Icons.account_balance),
                title: const Text('Net worth'),
                subtitle: const Text('Accounts + simulated investments - debts'),
                trailing: Text(money(s['netWorth']), style: Theme.of(context).textTheme.titleLarge),
              ),
            ),
            const SizedBox(height: 8),
            Text('Spending by category', style: Theme.of(context).textTheme.titleMedium),
            if (cats.isEmpty)
              const SizedBox(height: 120, child: EmptyState('No spending this month yet.'))
            else ...[
              SizedBox(
                height: 200,
                child: PieChart(PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 36,
                  sections: [
                    for (var i = 0; i < cats.length; i++)
                      PieChartSectionData(
                        value: toD(cats[i]['total']),
                        color: _colors[i % _colors.length],
                        title: '',
                        radius: 56,
                      ),
                  ],
                )),
              ),
              for (var i = 0; i < cats.length; i++)
                ListTile(
                  dense: true,
                  leading: CircleAvatar(radius: 6, backgroundColor: _colors[i % _colors.length]),
                  title: Text('${cats[i]['category']}'),
                  trailing: Text(money(cats[i]['total'])),
                ),
            ],
            const SizedBox(height: 8),
            Text('AI alerts', style: Theme.of(context).textTheme.titleMedium),
            recs.when(
              loading: () => const Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator()),
              error: (e, _) => const Text('Could not load alerts'),
              data: (list) => list.isEmpty
                  ? const Padding(padding: EdgeInsets.all(8), child: Text('No alerts. Spending looks normal.'))
                  : Column(children: [
                      for (final r in list.take(5))
                        Card(
                          color: Theme.of(context).colorScheme.errorContainer,
                          child: ListTile(leading: const Icon(Icons.warning_amber), title: Text('${r['message']}')),
                        ),
                    ]),
            ),
          ]);
        },
      ),
    );
  }

  Widget _stat(BuildContext context, String label, String value, Color c) => Expanded(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 4),
              FittedBox(child: Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c))),
            ]),
          ),
        ),
      );
}
