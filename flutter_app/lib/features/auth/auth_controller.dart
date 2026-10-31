import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../../core/network/finance_api.dart';
import '../../core/storage/token_storage.dart';

enum AuthStatus { unknown, loggedOut, loggedIn }

class AuthState {
  final AuthStatus status;
  final bool loading;
  final String? error;
  const AuthState({this.status = AuthStatus.unknown, this.loading = false, this.error});
}

final tokenStorageProvider = Provider((_) => TokenStorage());

final apiProvider = Provider<FinanceApi>((ref) {
  final client = ApiClient(ref.read(tokenStorageProvider), () => ref.read(authProvider.notifier).expired());
  return FinanceApi(client);
});

final authProvider = StateNotifierProvider<AuthController, AuthState>((ref) => AuthController(ref));

class AuthController extends StateNotifier<AuthState> {
  final Ref ref;
  AuthController(this.ref) : super(const AuthState()) {
    _boot();
  }

  Future<void> _boot() async {
    final t = await ref.read(tokenStorageProvider).access;
    state = AuthState(status: t == null ? AuthStatus.loggedOut : AuthStatus.loggedIn);
  }

  void expired() => state = const AuthState(status: AuthStatus.loggedOut, error: 'Session expired');

  Future<bool> login(String email, String password) => _auth(() => ref.read(apiProvider).login(email, password));

  Future<bool> register(String name, String email, String password) =>
      _auth(() => ref.read(apiProvider).register(name, email, password));

  Future<bool> _auth(Future<Map<String, dynamic>> Function() call) async {
    state = const AuthState(status: AuthStatus.loggedOut, loading: true);
    try {
      final r = await call();
      await ref.read(tokenStorageProvider).save(r['accessToken'], r['refreshToken']);
      state = const AuthState(status: AuthStatus.loggedIn);
      return true;
    } catch (e) {
      state = AuthState(status: AuthStatus.loggedOut, error: errorMessage(e));
      return false;
    }
  }

  Future<void> logout() async {
    final storage = ref.read(tokenStorageProvider);
    final rt = await storage.refresh;
    if (rt != null) {
      try {
        await ref.read(apiProvider).logout(rt);
      } catch (_) {}
    }
    await storage.clear();
    state = const AuthState(status: AuthStatus.loggedOut);
  }
}
