import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../auth/auth_controller.dart';

class _Msg {
  final String text;
  final bool mine;
  _Msg(this.text, this.mine);
}

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key});
  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _c = TextEditingController();
  final _scroll = ScrollController();
  final List<_Msg> _msgs = [_Msg('Hi! Ask me about your spending, e.g. "How much did I spend on food this month?"', false)];
  bool _busy = false;

  @override
  void dispose() {
    _c.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _c.text.trim();
    if (text.isEmpty || _busy) return;
    setState(() {
      _msgs.add(_Msg(text, true));
      _busy = true;
      _c.clear();
    });
    try {
      final r = await ref.read(apiProvider).chat(text);
      _msgs.add(_Msg('${r['reply']}', false));
    } catch (e) {
      _msgs.add(_Msg(errorMessage(e), false));
    }
    if (!mounted) return;
    setState(() => _busy = false);
    await Future.delayed(const Duration(milliseconds: 50));
    if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(children: [
      Expanded(
        child: ListView.builder(
          controller: _scroll,
          padding: const EdgeInsets.all(12),
          itemCount: _msgs.length,
          itemBuilder: (_, i) {
            final m = _msgs[i];
            return Align(
              alignment: m.mine ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.all(10),
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                decoration: BoxDecoration(
                  color: m.mine ? cs.primaryContainer : cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(m.text),
              ),
            );
          },
        ),
      ),
      if (_busy) const LinearProgressIndicator(),
      SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _c,
                maxLength: 500,
                onSubmitted: (_) => _send(),
                decoration: const InputDecoration(hintText: 'Ask about your finances', border: OutlineInputBorder(), counterText: ''),
              ),
            ),
            IconButton.filled(onPressed: _busy ? null : _send, icon: const Icon(Icons.send)),
          ]),
        ),
      ),
    ]);
  }
}
