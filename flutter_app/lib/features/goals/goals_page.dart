import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../../core/widgets/async_view.dart';
import '../auth/auth_controller.dart';

final goalsProvider = FutureProvider.autoDispose((ref) => ref.watch(apiProvider).goals());
final debtsProvider = FutureProvider.autoDispose((ref) => ref.watch(apiProvider).debts());

Future<double?> _askAmount(BuildContext context, String title) async {
  final c = TextEditingController();
  final v = await showDialog<double>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: c,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(prefixText: '\$ '),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(
            onPressed: () {
              final n = double.tryParse(c.text);
              if (n != null && n > 0) Navigator.pop(ctx, n);
            },
            child: const Text('OK')),
      ],
    ),
  );
  c.dispose();
  return v;
}

class GoalsPage extends ConsumerWidget {
  const GoalsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(goalsProvider);
    final debts = ref.watch(debtsProvider);
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(goalsProvider);
          ref.invalidate(debtsProvider);
        },
        child: ListView(padding: const EdgeInsets.all(12), children: [
          const _AdvisorCard(),
          Text('Savings goals', style: Theme.of(context).textTheme.titleMedium),
          goals.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text(errorMessage(e)),
            data: (list) => list.isEmpty
                ? const Padding(padding: EdgeInsets.all(12), child: Text('No goals yet. Tap + to add one.'))
                : Column(children: [
                    for (final g in list)
                      Card(
                        child: ListTile(
                          title: Text('${g['name']}'),
                          subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const SizedBox(height: 6),
                            LinearProgressIndicator(value: (toD(g['saved_amount']) / toD(g['target_amount'])).clamp(0.0, 1.0)),
                            Text('${money(g['saved_amount'])} / ${money(g['target_amount'])} by ${g['deadline']}'),
                          ]),
                          trailing: IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: () async {
                              final a = await _askAmount(context, 'Add to goal');
                              if (a == null) return;
                              try {
                                await ref.read(apiProvider).contribute(g['id'], a);
                                ref.invalidate(goalsProvider);
                              } catch (e) {
                                if (context.mounted) showSnack(context, errorMessage(e));
                              }
                            },
                          ),
                        ),
                      ),
                  ]),
          ),
          const SizedBox(height: 12),
          Text('Debts', style: Theme.of(context).textTheme.titleMedium),
          debts.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text(errorMessage(e)),
            data: (list) => list.isEmpty
                ? const Padding(padding: EdgeInsets.all(12), child: Text('No debts recorded.'))
                : Column(children: [
                    for (final d in list)
                      Card(
                        child: ListTile(
                          title: Text('${d['name']}'),
                          subtitle: Text('Remaining ${money(d['remaining'])} of ${money(d['principal'])} - ${d['interest_rate']}% interest'),
                          trailing: TextButton(
                            child: const Text('Pay'),
                            onPressed: () async {
                              final a = await _askAmount(context, 'Payment amount');
                              if (a == null) return;
                              try {
                                await ref.read(apiProvider).payDebt(d['id'], a);
                                ref.invalidate(debtsProvider);
                              } catch (e) {
                                if (context.mounted) showSnack(context, errorMessage(e));
                              }
                            },
                          ),
                        ),
                      ),
                  ]),
          ),
          const SizedBox(height: 80),
        ]),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addGoal(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _addGoal(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController();
    final target = TextEditingController();
    final months = TextEditingController(text: '6');
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New savings goal'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
          TextField(controller: target, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Target', prefixText: '\$ ')),
          TextField(controller: months, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Months from now')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final t = double.tryParse(target.text);
              final m = int.tryParse(months.text);
              if (name.text.trim().isEmpty || t == null || t <= 0 || m == null || m <= 0) return;
              final d = DateTime.now().add(Duration(days: 30 * m));
              final deadline = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
              try {
                await ref.read(apiProvider).addGoal(name.text.trim(), t, deadline);
                ref.invalidate(goalsProvider);
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (ctx.mounted) showSnack(ctx, errorMessage(e));
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
    name.dispose();
    target.dispose();
    months.dispose();
  }
}

class _AdvisorCard extends ConsumerStatefulWidget {
  const _AdvisorCard();
  @override
  ConsumerState<_AdvisorCard> createState() => _AdvisorCardState();
}

class _AdvisorCardState extends ConsumerState<_AdvisorCard> {
  final _goal = TextEditingController(text: '2000');
  final _months = TextEditingController(text: '6');
  Map<String, dynamic>? _result;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _goal.dispose();
    _months.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final g = double.tryParse(_goal.text);
    final m = int.tryParse(_months.text);
    if (g == null || g <= 0 || m == null || m <= 0) {
      setState(() => _error = 'Enter a goal amount and number of months');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await ref.read(apiProvider).advisor(g, m, 0);
      setState(() => _result = r);
    } catch (e) {
      setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.auto_awesome),
            const SizedBox(width: 8),
            Text('AI Budget Advisor', style: Theme.of(context).textTheme.titleMedium),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextField(controller: _goal, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'I want to save', prefixText: '\$ '))),
            const SizedBox(width: 12),
            Expanded(child: TextField(controller: _months, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'in months'))),
          ]),
          const SizedBox(height: 8),
          FilledButton(onPressed: _busy ? null : _run, child: Text(_busy ? 'Calculating...' : 'Analyse')),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!)),
          if (r != null) ...[
            const Divider(),
            Text('Required: ${money(r['required_monthly'])}/month'),
            Text('Your average surplus: ${money(r['monthly_surplus'])}/month'),
            Text(r['feasible'] == true ? 'Achievable with your current habits.' : 'Short by ${money(r['gap'])}/month.',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            for (final s in (r['suggestions'] as List)) Text('- ${s['note']}'),
          ],
        ]),
      ),
    );
  }
}
