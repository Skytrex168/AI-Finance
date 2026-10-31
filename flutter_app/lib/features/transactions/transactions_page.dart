import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../../core/widgets/async_view.dart';
import '../auth/auth_controller.dart';
import '../dashboard/dashboard_page.dart';

final txnProvider =
    FutureProvider.autoDispose((ref) => ref.watch(apiProvider).transactions());
final accountsProvider =
    FutureProvider.autoDispose((ref) => ref.watch(apiProvider).accounts());
final categoriesProvider =
    FutureProvider.autoDispose((ref) => ref.watch(apiProvider).categories());

class TransactionsPage extends ConsumerWidget {
  const TransactionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txns = ref.watch(txnProvider);
    return Scaffold(
      body: AsyncView<List<dynamic>>(
        value: txns,
        onRetry: () => ref.invalidate(txnProvider),
        builder: (list) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(txnProvider),
          child: list.isEmpty
              ? ListView(children: const [
                  SizedBox(
                      height: 200,
                      child:
                          EmptyState('No transactions yet. Tap + to add one.'))
                ])
              : ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final t = list[i] as Map<String, dynamic>;
                    final income = t['type'] == 'INCOME';
                    final anomaly = t['is_anomaly'] == true;
                    return Dismissible(
                      key: ValueKey(t['id']),
                      direction: DismissDirection.endToStart,
                      background: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 16),
                          child: const Icon(Icons.delete, color: Colors.white)),
                      confirmDismiss: (_) async {
                        try {
                          await ref
                              .read(apiProvider)
                              .deleteTransaction(t['id']);
                          ref.invalidate(summaryProvider);
                          return true;
                        } catch (e) {
                          if (context.mounted) {
                            showSnack(context, errorMessage(e));
                          }
                          return false;
                        }
                      },
                      child: ListTile(
                        leading: Icon(
                            anomaly
                                ? Icons.warning_amber
                                : (income
                                    ? Icons.arrow_downward
                                    : Icons.arrow_upward),
                            color: anomaly
                                ? Colors.orange
                                : (income ? Colors.green : Colors.red)),
                        title: Text('${t['description']}'),
                        subtitle: Text([
                          '${t['category'] ?? 'Uncategorized'}',
                          '${t['txn_date']}',
                          if (t['ai_confidence'] != null)
                            'AI ${(toD(t['ai_confidence']) * 100).round()}%',
                          if (anomaly) 'Unusual!',
                        ].join(' - ')),
                        trailing: Text(
                            '${income ? '+' : '-'}${money(t['amount'])}',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: income ? Colors.green : null)),
                      ),
                    );
                  },
                ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (_) => const _AddTxnSheet(),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _AddTxnSheet extends ConsumerStatefulWidget {
  const _AddTxnSheet();
  @override
  ConsumerState<_AddTxnSheet> createState() => _AddTxnSheetState();
}

class _AddTxnSheetState extends ConsumerState<_AddTxnSheet> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _desc = TextEditingController();
  String _type = 'EXPENSE';
  int? _account;
  bool _busy = false;
  late final String _key =
      'txn-${DateTime.now().microsecondsSinceEpoch}'; // idempotency key per form

  @override
  void dispose() {
    _amount.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate() || _account == null) return;
    setState(() => _busy = true);
    try {
      final r = await ref.read(apiProvider).addTransaction({
        'accountId': _account,
        'type': _type,
        'amount': double.parse(_amount.text),
        'description': _desc.text.trim(),
      }, _key);
      ref.invalidate(txnProvider);
      ref.invalidate(summaryProvider);
      ref.invalidate(recsProvider);
      ref.invalidate(accountsProvider);
      if (!mounted) return;
      Navigator.pop(context);
      showSnack(
          context,
          r['isAnomaly'] == true
              ? 'Saved. AI flagged this as unusual: ${r['anomalyReason']}'
              : 'Saved. Category assigned by AI.');
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showSnack(context, errorMessage(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsProvider);
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: Form(
        key: _form,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'EXPENSE', label: Text('Expense')),
              ButtonSegment(value: 'INCOME', label: Text('Income')),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _desc,
            decoration: const InputDecoration(
                labelText: 'Description (AI will categorize)',
                border: OutlineInputBorder()),
            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
                labelText: 'Amount',
                prefixText: '\$ ',
                border: OutlineInputBorder()),
            validator: (v) {
              final n = double.tryParse(v ?? '');
              return n == null || n <= 0
                  ? 'Enter an amount greater than 0'
                  : null;
            },
          ),
          const SizedBox(height: 12),
          accounts.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text(errorMessage(e)),
            data: (list) {
              _account ??= list.isEmpty ? null : list.first['id'] as int;
              return DropdownButtonFormField<int>(
                initialValue: _account,
                decoration: const InputDecoration(
                    labelText: 'Account', border: OutlineInputBorder()),
                items: [
                  for (final a in list)
                    DropdownMenuItem(
                        value: a['id'] as int, child: Text('${a['name']}'))
                ],
                onChanged: (v) => setState(() => _account = v),
              );
            },
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
                onPressed: _busy ? null : _submit,
                child: Text(_busy ? 'Saving...' : 'Save')),
          ),
        ]),
      ),
    );
  }
}
