import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../../core/widgets/async_view.dart';
import '../auth/auth_controller.dart';

final portfolioProvider = FutureProvider.autoDispose((ref) => ref.watch(apiProvider).portfolio());
final assetsProvider = FutureProvider.autoDispose((ref) => ref.watch(apiProvider).assets());

class InvestPage extends ConsumerStatefulWidget {
  const InvestPage({super.key});
  @override
  ConsumerState<InvestPage> createState() => _InvestPageState();
}

class _InvestPageState extends ConsumerState<InvestPage> {
  double _risk = 3;
  Map<String, dynamic>? _alloc;

  Future<void> _trade(Map<String, dynamic> asset, String side) async {
    final c = TextEditingController();
    final qty = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$side ${asset['symbol']} @ ${money(asset['price'])}'),
        content: TextField(controller: c, autofocus: true, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Quantity')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () {
                final n = double.tryParse(c.text);
                if (n != null && n > 0) Navigator.pop(ctx, n);
              },
              child: Text(side)),
        ],
      ),
    );
    c.dispose();
    if (qty == null) return;
    try {
      await ref.read(apiProvider).trade(asset['id'] ?? asset['asset_id'], side, qty);
      ref.invalidate(portfolioProvider);
      if (mounted) showSnack(context, 'Simulated $side completed');
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e));
    }
  }

  Future<void> _suggest() async {
    try {
      final r = await ref.read(apiProvider).allocation(_risk.round());
      setState(() => _alloc = r);
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final pf = ref.watch(portfolioProvider);
    final assets = ref.watch(assetsProvider);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(portfolioProvider);
        ref.invalidate(assetsProvider);
      },
      child: ListView(padding: const EdgeInsets.all(12), children: [
        const Card(child: Padding(padding: EdgeInsets.all(12), child: Text('Simulation only. No real money or real trading. Educational, not financial advice.'))),
        pf.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text(errorMessage(e)),
          data: (p) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Card(
              child: ListTile(
                title: Text('Portfolio value ${money(p['total'])}'),
                subtitle: Text('Simulated cash ${money(p['cash'])}'),
              ),
            ),
            for (final h in (p['holdings'] as List))
              Card(
                child: ListTile(
                  title: Text('${h['symbol']}  x ${toD(h['quantity']).toStringAsFixed(4)}'),
                  subtitle: Text('Value ${money(h['value'])}  -  P/L ${money(h['profit'])}'),
                  trailing: TextButton(onPressed: () => _trade(h.cast<String, dynamic>(), 'SELL'), child: const Text('Sell')),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 8),
        Text('Market (simulated)', style: Theme.of(context).textTheme.titleMedium),
        assets.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text(errorMessage(e)),
          data: (list) => Column(children: [
            for (final a in list)
              Card(
                child: ListTile(
                  title: Text('${a['symbol']} - ${a['name']}'),
                  subtitle: Text('${a['asset_type']}  -  risk ${a['risk_level']}/5  -  ${money(a['price'])}'),
                  trailing: FilledButton.tonal(onPressed: () => _trade(Map<String, dynamic>.from(a), 'BUY'), child: const Text('Buy')),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 8),
        Text('AI allocation suggestion', style: Theme.of(context).textTheme.titleMedium),
        Slider(value: _risk, min: 1, max: 5, divisions: 4, label: 'Risk ${_risk.round()}', onChanged: (v) => setState(() => _risk = v)),
        Align(alignment: Alignment.centerLeft, child: Text('Risk tolerance: ${_risk.round()} / 5')),
        FilledButton(onPressed: _suggest, child: const Text('Suggest allocation')),
        if (_alloc != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Stocks ${_alloc!['STOCK']}%  Funds ${_alloc!['FUND']}%  Bonds ${_alloc!['BOND']}%  Crypto ${_alloc!['CRYPTO']}%\n${_alloc!['disclaimer']}'),
          ),
        const SizedBox(height: 24),
      ]),
    );
  }
}
