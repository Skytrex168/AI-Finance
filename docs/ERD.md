# ERD (Mermaid: paste into https://mermaid.live or render in GitHub)

```mermaid
erDiagram
  ROLES ||--o{ USERS : "1:N"
  USERS ||--o{ REFRESH_TOKENS : "1:N"
  USERS ||--o{ ACCOUNTS : "1:N"
  USERS ||--o{ CATEGORIES : "1:N (custom)"
  USERS ||--o{ TRANSACTIONS : "1:N"
  ACCOUNTS ||--o{ TRANSACTIONS : "1:N"
  CATEGORIES ||--o{ TRANSACTIONS : "1:N"
  USERS ||--o{ BUDGETS : "1:N"
  CATEGORIES ||--o{ BUDGETS : "1:N"
  USERS ||--o{ GOALS : "1:N"
  USERS ||--o{ DEBTS : "1:N"
  USERS ||--|| PORTFOLIOS : "1:1"
  PORTFOLIOS ||--o{ PORTFOLIO_HOLDINGS : "1:N"
  ASSETS ||--o{ PORTFOLIO_HOLDINGS : "1:N  (N:M portfolio-asset)"
  USERS ||--o{ RECOMMENDATIONS : "1:N"
  USERS ||--o{ AUDIT_LOGS : "1:N"
```

Relationship summary
- **1:1** users - portfolios
- **1:N** users - accounts / transactions / budgets / goals / debts / recommendations / audit_logs
- **N:M** portfolios - assets, resolved by `portfolio_holdings`

Design features: PK/FK, CHECK constraints, UNIQUE keys (e.g. `UNIQUE(user_id, idempotency_key)` blocks duplicate transactions), indexes on `(user_id, txn_date)`, `created_at/updated_at`, soft delete (`deleted_at`) and `audit_logs`.
