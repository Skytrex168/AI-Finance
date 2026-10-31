# Security checklist (implemented)
- Passwords hashed with BCrypt; JWT access token (15 min) + rotating refresh token (stored as SHA-256 hash).
- Role-based authorization on the server (`/api/admin/**` needs ADMIN); roles are never trusted from the client.
- Every query is scoped by the authenticated user id (no access to other users' rows); parameterised SQL only.
- Input validation (Jakarta Validation) and generic error messages (no stack traces/secrets).
- Secrets via environment variables (`.env`, not committed); AI service protected by an internal key and not exposed through nginx.
- Flutter stores tokens in secure storage; no API keys in the app.
- Rate limiting on `/api/auth/**` (in-memory; use Redis for several instances); audit log for login, transactions, trades.
- Idempotency-Key prevents duplicate transactions.
- Production TODO: HTTPS in nginx, disable `SEED_DEMO`, rotate secrets.

# Test plan
| Area | Test | Where |
|---|---|---|
| AI | categorisation, anomaly, budget maths, grounded chat | `ai-service/tests/test_core.py` |
| Backend | JWT create/parse/expired/tampered/short secret | `backend/src/test/.../JwtServiceTest.java` |
| Flutter | money format, login validation, empty state | `flutter_app/test/widget_test.dart` |
| Security (manual, Postman/curl) | invalid login -> 401; expired token -> 401; no token -> 401; USER on `/api/admin/audit-logs` -> 403; invalid input -> 400; same Idempotency-Key twice -> one transaction |

Suggested extra tests for the report: Spring `@SpringBootTest` with Testcontainers (PostgreSQL), Flutter `integration_test` for login -> add transaction.
