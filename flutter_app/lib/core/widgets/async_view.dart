import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/api_client.dart';

/// Standard loading / error (with retry) / data rendering for FutureProviders.
class AsyncView<T> extends StatelessWidget {
  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final VoidCallback onRetry;
  const AsyncView({super.key, required this.value, required this.builder, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return value.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off, size: 48),
            const SizedBox(height: 8),
            Text(errorMessage(e), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ]),
        ),
      ),
      data: builder,
    );
  }
}

class EmptyState extends StatelessWidget {
  final String message;
  const EmptyState(this.message, {super.key});
  @override
  Widget build(BuildContext context) => Center(
      child: Padding(padding: const EdgeInsets.all(32), child: Text(message, textAlign: TextAlign.center)));
}

void showSnack(BuildContext context, String msg) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

double toD(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
String money(dynamic v) => '\$${toD(v).toStringAsFixed(2)}';
