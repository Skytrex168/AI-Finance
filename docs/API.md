# REST API

Base URL `http://localhost:8080`. Auth = `Authorization: Bearer <accessToken>` unless noted. Errors are `{ "error": "message" }`.
Common errors: 400 validation, 401 missing/expired token, 403 wrong role, 404 not found, 409 conflict, 429 rate limit, 500 server.

| Method | URL | Auth | Request body | Success response |
|---|---|---|---|---|
| POST | /api/auth/register | none | `{fullName,email,password(min 8)}` | 201 `{accessToken,refreshToken,role}` (409 email exists) |
| POST | /api/auth/login | none | `{email,password}` | 200 tokens (401 invalid) |
| POST | /api/auth/refresh | none | `{refreshToken}` | 200 new tokens (rotation, old token revoked) |
| POST | /api/auth/logout | none | `{refreshToken}` | 200 `{status}` |
| GET | /api/users/me | USER | - | `{id,email,full_name,currency,role}` |
| GET/POST | /api/accounts | USER | `{name,type,balance}` | list / 201 `{id}` |
| GET | /api/categories | USER | - | list |
| GET | /api/transactions?month=YYYY-MM | USER | - | list (includes ai_confidence, is_anomaly) |
| POST | /api/transactions | USER | `{accountId,type,amount,description,date?,categoryId?}` + header `Idempotency-Key` | 201 `{id,categoryId,aiConfidence,isAnomaly,anomalyScore,anomalyReason}`; duplicate key returns 200 `{duplicate:true}` |
| DELETE | /api/transactions/{id} | USER | - | soft delete, balance reversed |
| GET | /api/analytics/summary?month= | USER | - | `{income,expense,savings,byCategory[],netWorth}` |
| GET/POST/DELETE | /api/budgets | USER | `{categoryId,month,limitAmount}` | budgets with `spent` |
| GET/POST | /api/goals, POST /api/goals/{id}/contribute | USER | `{name,targetAmount,deadline}` / `{amount}` | |
| GET/POST | /api/debts, POST /api/debts/{id}/pay | USER | `{name,principal,interestRate}` / `{amount}` | |
| GET | /api/investments/assets, /portfolio | USER | - | simulated market / portfolio |
| POST | /api/investments/trade | USER | `{assetId,side:BUY\|SELL,quantity}` | simulated trade (400 if insufficient cash/units) |
| GET | /api/investments/suggestion?risk=1..5 | USER | - | allocation percentages |
| POST | /api/ai/advisor | USER | `{goalAmount,months,savedSoFar?}` | `{required_monthly,monthly_surplus,gap,feasible,suggestions[]}` |
| POST | /api/ai/chat | USER | `{message}` | `{reply,source}` |
| GET | /api/recommendations | USER | - | anomaly alerts |
| GET | /api/admin/audit-logs | ADMIN | - | audit trail (403 for USER) |

Internal AI service (not exposed by nginx, needs `X-Internal-Key`): `/categorize`, `/anomaly`, `/advisor`, `/allocation`, `/chat`.
