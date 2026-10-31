# AI Personal Finance & Investment Advisor (Project 4)

Flutter + Spring Boot + PostgreSQL + Python AI service, packaged with Docker.

```
Flutter app -> Nginx -> Spring Boot API (JWT, RBAC, JDBC) -> PostgreSQL
                              |
                              +-> AI service (FastAPI): categorize / anomaly / advisor / chat
```

## Features
Auth (register, login, refresh, logout, roles) - accounts - income/expense with AI auto-categorisation and anomaly flags - categories - monthly budgets - savings goals - debts - net worth - simulated investments (stocks, funds, bonds, crypto) - AI budget advisor ("save $2,000 in 6 months") - grounded AI assistant - audit log (admin).

## Run the backend (Docker)
```bash
cp .env.example .env        # edit secrets
docker compose up --build
# API: http://localhost:8080   health: /actuator/health
```
Demo users (created when SEED_DEMO=true): `demo@finance.app / Demo@1234`, `admin@finance.app / Admin@1234`.

## Run the Flutter app
```bash
cd flutter_app
flutter create . --platforms=android,ios     # generates android/ ios/ folders once
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080   # Android emulator
```
- iOS simulator / desktop: use `http://localhost:8080`. Real phone: use your PC's LAN IP.
- Android over plain http (dev only): add `android:usesCleartextTraffic="true"` to `<application>` in `android/app/src/main/AndroidManifest.xml`; internet permission is added by `flutter create`.

## Run AI service alone (no Docker)
```bash
cd ai-service && pip install -r requirements.txt
uvicorn app.main:app --port 8000
python -m tests.evaluate          # accuracy / precision / recall
```

## Backend without Docker
PostgreSQL 16, run `database/schema.sql` then `database/sample_data.sql`, then
`cd backend && JWT_SECRET=<32+ chars> mvn spring-boot:run` (Java 21).

## Folders
`database/` SQL + `docs/ERD.md` - `backend/` Spring Boot - `ai-service/` FastAPI + tests - `flutter_app/lib/` core + features - `docs/` API, AI, security/testing - `.github/workflows/ci.yml` CI.

## Milestone mapping (from the course PDF)
M1-M2 requirements/UI: write from this README + screens - M3 database: `database/`, `docs/ERD.md` - M4 backend: `backend/` - M5 Flutter: `flutter_app/` - M6 AI: `ai-service/`, `docs/AI_DOCUMENTATION.md` - M7 testing: `docs/SECURITY_AND_TESTING.md` - M8 DevOps: `docker-compose.yml`, CI.

## Known limits / future work
RAG over a finance FAQ, Redis (cache + distributed rate limit), refresh-token device management, charts per month, push notifications, tests with Testcontainers.
