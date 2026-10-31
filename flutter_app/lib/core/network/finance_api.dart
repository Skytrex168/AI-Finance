import 'package:dio/dio.dart';
import 'api_client.dart';

/// Thin typed wrapper over the REST API (responses are decoded JSON).
class FinanceApi {
  final ApiClient client;
  FinanceApi(this.client);
  Dio get _d => client.dio;

  Future<Map<String, dynamic>> login(String email, String password) async =>
      (await _d.post('/api/auth/login',
              data: {'email': email, 'password': password}))
          .data;
  Future<Map<String, dynamic>> register(
          String name, String email, String password) async =>
      (await _d.post('/api/auth/register',
              data: {'fullName': name, 'email': email, 'password': password}))
          .data;
  Future<void> logout(String refreshToken) =>
      _d.post('/api/auth/logout', data: {'refreshToken': refreshToken});

  Future<Map<String, dynamic>> me() async =>
      (await _d.get('/api/users/me')).data;
  Future<List<dynamic>> accounts() async =>
      (await _d.get('/api/accounts')).data;
  Future<List<dynamic>> categories() async =>
      (await _d.get('/api/categories')).data;
  Future<List<dynamic>> transactions() async =>
      (await _d.get('/api/transactions')).data;

  Future<Map<String, dynamic>> addTransaction(
          Map<String, dynamic> body, String idempotencyKey) async =>
      (await _d.post('/api/transactions',
              data: body,
              options: Options(headers: {'Idempotency-Key': idempotencyKey})))
          .data;
  Future<void> deleteTransaction(int id) => _d.delete('/api/transactions/$id');

  Future<Map<String, dynamic>> summary() async =>
      (await _d.get('/api/analytics/summary')).data;
  Future<List<dynamic>> recommendations() async =>
      (await _d.get('/api/recommendations')).data;

  Future<List<dynamic>> budgets() async => (await _d.get('/api/budgets')).data;
  Future<void> setBudget(int categoryId, String month, double limit) => _d.post(
      '/api/budgets',
      data: {'categoryId': categoryId, 'month': month, 'limitAmount': limit});
  Future<void> deleteBudget(int id) => _d.delete('/api/budgets/$id');

  Future<List<dynamic>> goals() async => (await _d.get('/api/goals')).data;
  Future<void> addGoal(String name, double target, String deadline) =>
      _d.post('/api/goals',
          data: {'name': name, 'targetAmount': target, 'deadline': deadline});
  Future<void> contribute(int id, double amount) =>
      _d.post('/api/goals/$id/contribute', data: {'amount': amount});

  Future<List<dynamic>> debts() async => (await _d.get('/api/debts')).data;
  Future<void> addDebt(String name, double principal, double rate) =>
      _d.post('/api/debts',
          data: {'name': name, 'principal': principal, 'interestRate': rate});
  Future<void> payDebt(int id, double amount) =>
      _d.post('/api/debts/$id/pay', data: {'amount': amount});

  Future<List<dynamic>> assets() async =>
      (await _d.get('/api/investments/assets')).data;
  Future<Map<String, dynamic>> portfolio() async =>
      (await _d.get('/api/investments/portfolio')).data;
  Future<void> trade(int assetId, String side, double qty) =>
      _d.post('/api/investments/trade',
          data: {'assetId': assetId, 'side': side, 'quantity': qty});
  Future<Map<String, dynamic>> allocation(int risk) async => (await _d
          .get('/api/investments/suggestion', queryParameters: {'risk': risk}))
      .data;

  Future<Map<String, dynamic>> advisor(
          double goal, int months, double saved) async =>
      (await _d.post('/api/ai/advisor', data: {
        'goalAmount': goal,
        'months': months,
        'savedSoFar': saved
      }))
          .data;
  Future<Map<String, dynamic>> chat(String message) async =>
      (await _d.post('/api/ai/chat', data: {'message': message})).data;

  Future<List<dynamic>> auditLogs() async =>
      (await _d.get('/api/admin/audit-logs')).data;
}
