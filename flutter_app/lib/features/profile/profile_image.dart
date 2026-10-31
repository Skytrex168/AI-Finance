import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';

final avatarProvider = StateNotifierProvider.autoDispose
    .family<AvatarController, Uint8List?, int>(
        (ref, userId) => AvatarController(userId));

class AvatarController extends StateNotifier<Uint8List?> {
  final int userId;
  final FlutterSecureStorage _s = const FlutterSecureStorage();

  AvatarController(this.userId) : super(null) {
    _load();
  }

  String get _key => 'avatar_$userId';

  Future<void> _load() async {
    final v = await _s.read(key: _key);
    if (v != null && mounted) state = base64Decode(v);
  }

  Future<void> pick(ImageSource source) async {
    final x = await ImagePicker().pickImage(
      source: source,
      maxWidth: 400,
      maxHeight: 400,
      imageQuality: 75,
    );
    if (x == null) return;
    final bytes = await x.readAsBytes();
    await _s.write(key: _key, value: base64Encode(bytes));
    if (mounted) state = bytes;
  }

  Future<void> remove() async {
    await _s.delete(key: _key);
    if (mounted) state = null;
  }
}
