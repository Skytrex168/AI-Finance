package com.finance.app.web;

import com.finance.app.service.AiClient;
import com.finance.app.service.Audit;
import com.finance.app.service.PerformanceService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.time.YearMonth;
import java.util.*;

@RestController
@RequestMapping("/api")
public class ApiController {
    record AccountReq(@NotBlank @Size(max = 80) String name,
            @NotBlank @Pattern(regexp = "CASH|BANK|SAVINGS|CARD|WALLET") String type,
            @NotNull BigDecimal balance) {
    }

    record TxnReq(@NotNull Long accountId, @NotBlank @Pattern(regexp = "INCOME|EXPENSE") String type,
            @NotNull @DecimalMin("0.01") @Digits(integer = 12, fraction = 2) BigDecimal amount,
            @NotBlank @Size(max = 255) String description, LocalDate date, Long categoryId) {
    }

    record BudgetReq(@NotNull Long categoryId, @NotBlank @Pattern(regexp = "\\d{4}-\\d{2}") String month,
            @NotNull @DecimalMin("0.01") BigDecimal limitAmount) {
    }

    record GoalReq(@NotBlank @Size(max = 100) String name, @NotNull @DecimalMin("0.01") BigDecimal targetAmount,
            @NotNull @Future LocalDate deadline) {
    }

    record AmountReq(@NotNull @DecimalMin("0.01") BigDecimal amount) {
    }

    record DebtReq(@NotBlank @Size(max = 100) String name, @NotNull @DecimalMin("0.01") BigDecimal principal,
            @NotNull @DecimalMin("0") @DecimalMax("100") BigDecimal interestRate, LocalDate dueDate) {
    }

    record TradeReq(@NotNull Long assetId, @NotBlank @Pattern(regexp = "BUY|SELL") String side,
            @NotNull @DecimalMin("0.0001") BigDecimal quantity) {
    }

    record AdvisorReq(@NotNull @DecimalMin("1") BigDecimal goalAmount, @Min(1) @Max(600) int months,
            BigDecimal savedSoFar) {
    }

    record ChatReq(@NotBlank @Size(max = 500) String message) {
    }

    private final JdbcTemplate jdbc;
    private final AiClient ai;
    private final Audit audit;
    private final PerformanceService perf;

    public ApiController(JdbcTemplate jdbc, AiClient ai, Audit audit, PerformanceService perf) {
        this.jdbc = jdbc;
        this.ai = ai;
        this.audit = audit; this.perf = perf;
    }

    private List<Map<String, Object>> q(String sql, Object... args) {
        return jdbc.queryForList(sql, args);
    }

    private Map<String, Object> one(String sql, String notFound, Object... args) {
        List<Map<String, Object>> r = q(sql, args);
        if (r.isEmpty())
            throw new ApiException(HttpStatus.NOT_FOUND, notFound);
        return r.get(0);
    }

    private BigDecimal sum(String sql, Object... args) {
        BigDecimal v = jdbc.queryForObject(sql, BigDecimal.class, args);
        return v == null ? BigDecimal.ZERO : v;
    }

    // ---------------- profile / accounts / categories ----------------
    @GetMapping("/users/me")
    public Map<String, Object> me(@AuthenticationPrincipal Long uid) {
        return one(
                "SELECT u.id, u.email, u.full_name, u.currency, r.name AS role FROM users u JOIN roles r ON r.id=u.role_id WHERE u.id=?",
                "User not found", uid);
    }

    @GetMapping("/accounts")
    public List<Map<String, Object>> accounts(@AuthenticationPrincipal Long uid) {
        return q("SELECT id, name, type, balance FROM accounts WHERE user_id=? AND deleted_at IS NULL ORDER BY id",
                uid);
    }

    @PostMapping("/accounts")
    @ResponseStatus(HttpStatus.CREATED)
    public Map<String, Object> addAccount(@AuthenticationPrincipal Long uid, @Valid @RequestBody AccountReq r) {
        Long id = jdbc.queryForObject("INSERT INTO accounts(user_id,name,type,balance) VALUES (?,?,?,?) RETURNING id",
                Long.class, uid, r.name(), r.type(), r.balance());
        return Map.of("id", id);
    }

    @GetMapping("/categories")
    public List<Map<String, Object>> categories(@AuthenticationPrincipal Long uid) {
        return q("SELECT id, name, kind FROM categories WHERE user_id IS NULL OR user_id=? ORDER BY kind, name", uid);
    }

    // ---------------- transactions ----------------
    @GetMapping("/transactions")
    public List<Map<String, Object>> transactions(@AuthenticationPrincipal Long uid,
            @RequestParam(required = false) String month) {
        String base = "SELECT t.id, t.type, t.amount, t.description, t.txn_date, t.ai_confidence, t.is_anomaly, " +
                "t.anomaly_score, t.anomaly_reason, c.name AS category, a.name AS account FROM transactions t " +
                "LEFT JOIN categories c ON c.id=t.category_id JOIN accounts a ON a.id=t.account_id " +
                "WHERE t.user_id=? AND t.deleted_at IS NULL ";
        if (month != null) {
            LocalDate s = parseMonth(month).atDay(1);
            return q(base + "AND t.txn_date>=? AND t.txn_date<? ORDER BY t.txn_date DESC, t.id DESC", uid, s,
                    s.plusMonths(1));
        }
        return q(base + "ORDER BY t.txn_date DESC, t.id DESC LIMIT 100", uid);
    }

    @PostMapping("/transactions")
    @Transactional
    public org.springframework.http.ResponseEntity<Map<String, Object>> addTransaction(
            @AuthenticationPrincipal Long uid, @RequestHeader(value = "Idempotency-Key", required = false) String key,
            @Valid @RequestBody TxnReq r) {
        if (key != null) {
            List<Map<String, Object>> dup = q("SELECT id FROM transactions WHERE user_id=? AND idempotency_key=?", uid,
                    key);
            if (!dup.isEmpty())
                return org.springframework.http.ResponseEntity
                        .ok(Map.of("id", dup.get(0).get("id"), "duplicate", true));
        }
        one("SELECT id FROM accounts WHERE id=? AND user_id=? AND deleted_at IS NULL", "Account not found",
                r.accountId(), uid);

        Long categoryId = r.categoryId();
        BigDecimal confidence = null;
        if (categoryId == null) {
            Map<String, Object> cat = ai.post("/categorize", Map.of("description", r.description()));
            String name = cat == null ? null : (String) cat.get("category");
            if (cat != null)
                confidence = new BigDecimal(String.valueOf(cat.get("confidence"))).setScale(3, RoundingMode.HALF_UP);
            boolean income = r.type().equals("INCOME");
            if (name == null || (income && !List.of("Salary", "Freelance", "Other Income").contains(name)))
                name = income ? "Other Income" : "Other";
            if (!income && (name.equals("Salary") || name.equals("Freelance")))
                name = "Other";
            categoryId = q("SELECT id FROM categories WHERE name=? AND (user_id IS NULL OR user_id=?) LIMIT 1", name,
                    uid)
                    .stream().findFirst().map(m -> ((Number) m.get("id")).longValue()).orElse(null);
        } else {
            one("SELECT id FROM categories WHERE id=? AND (user_id IS NULL OR user_id=?)", "Category not found",
                    categoryId, uid);
        }

        BigDecimal score = BigDecimal.ZERO;
        boolean anomaly = false;
        String reason = null;
        if (r.type().equals("EXPENSE") && categoryId != null) {
            List<BigDecimal> hist = jdbc.queryForList(
                    "SELECT amount FROM transactions WHERE user_id=? AND category_id=? AND type='EXPENSE' " +
                            "AND deleted_at IS NULL AND txn_date >= CURRENT_DATE - 90",
                    BigDecimal.class, uid, categoryId);
            Map<String, Object> res = ai.post("/anomaly", Map.of("amount", r.amount(), "history", hist));
            if (res != null) {
                score = new BigDecimal(String.valueOf(res.get("score"))).setScale(3, RoundingMode.HALF_UP);
                anomaly = Boolean.TRUE.equals(res.get("is_anomaly"));
                reason = (String) res.get("reason");
            }
        }
        LocalDate date = r.date() == null ? LocalDate.now() : r.date();
        Long id = jdbc.queryForObject(
                "INSERT INTO transactions(user_id,account_id,category_id,type,amount,description,txn_date," +
                        "ai_confidence,anomaly_score,is_anomaly,anomaly_reason,idempotency_key) VALUES (?,?,?,?,?,?,?,?,?,?,?,?) RETURNING id",
                Long.class, uid, r.accountId(), categoryId, r.type(), r.amount(), r.description().trim(), date,
                confidence, score, anomaly, reason, key);
        BigDecimal delta = r.type().equals("INCOME") ? r.amount() : r.amount().negate();
        jdbc.update("UPDATE accounts SET balance=balance+?, updated_at=now() WHERE id=?", delta, r.accountId());
        if (anomaly) {
            jdbc.update("INSERT INTO recommendations(user_id,kind,message) VALUES (?,?,?)", uid, "ANOMALY",
                    "Unusual transaction: " + r.description() + " ($" + r.amount() + "). " + reason);
        }
        audit.log(uid, "TXN_CREATE", "id=" + id + " amount=" + r.amount());
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("id", id);
        out.put("categoryId", categoryId);
        out.put("aiConfidence", confidence);
        out.put("isAnomaly", anomaly);
        out.put("anomalyScore", score);
        out.put("anomalyReason", reason);
        return org.springframework.http.ResponseEntity.status(HttpStatus.CREATED).body(out);
    }

    @DeleteMapping("/transactions/{id}")
    @Transactional
    public Map<String, String> deleteTransaction(@AuthenticationPrincipal Long uid, @PathVariable long id) {
        Map<String, Object> t = one(
                "SELECT account_id, type, amount FROM transactions WHERE id=? AND user_id=? AND deleted_at IS NULL",
                "Transaction not found", id, uid);
        BigDecimal amt = (BigDecimal) t.get("amount");
        BigDecimal undo = "INCOME".equals(t.get("type")) ? amt.negate() : amt;
        jdbc.update("UPDATE transactions SET deleted_at=now() WHERE id=?", id);
        jdbc.update("UPDATE accounts SET balance=balance+?, updated_at=now() WHERE id=?", undo, t.get("account_id"));
        audit.log(uid, "TXN_DELETE", "id=" + id);
        return Map.of("status", "deleted");
    }

    // ---------------- analytics ----------------
    private YearMonth parseMonth(String m) {
        try {
            return m == null ? YearMonth.now() : YearMonth.parse(m);
        } catch (Exception e) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "month must be YYYY-MM");
        }
    }

    private Map<String, Object> monthSummary(long uid, YearMonth ym) {
        LocalDate s = ym.atDay(1), e = s.plusMonths(1);
        String f = " FROM transactions WHERE user_id=? AND deleted_at IS NULL AND txn_date>=? AND txn_date<? ";
        BigDecimal income = sum("SELECT coalesce(sum(amount),0)" + f + "AND type='INCOME'", uid, s, e);
        BigDecimal expense = sum("SELECT coalesce(sum(amount),0)" + f + "AND type='EXPENSE'", uid, s, e);
        List<Map<String, Object>> byCat = q(
                "SELECT coalesce(c.name,'Other') AS category, sum(t.amount) AS total FROM transactions t " +
                        "LEFT JOIN categories c ON c.id=t.category_id WHERE t.user_id=? AND t.deleted_at IS NULL AND t.type='EXPENSE' "
                        +
                        "AND t.txn_date>=? AND t.txn_date<? GROUP BY c.name ORDER BY total DESC",
                uid, s, e);
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("month", ym.toString());
        out.put("income", income);
        out.put("expense", expense);
        out.put("savings", income.subtract(expense));
        out.put("byCategory", byCat);
        return out;
    }

    @GetMapping("/analytics/summary")
    public Map<String, Object> summary(@AuthenticationPrincipal Long uid,
            @RequestParam(required = false) String month) {
        Map<String, Object> out = monthSummary(uid, parseMonth(month));
        BigDecimal accounts = sum(
                "SELECT coalesce(sum(balance),0) FROM accounts WHERE user_id=? AND deleted_at IS NULL", uid);
        BigDecimal debts = sum("SELECT coalesce(sum(remaining),0) FROM debts WHERE user_id=? AND deleted_at IS NULL",
                uid);
        BigDecimal invest = portfolioTotal(uid);
        out.put("netWorth", accounts.add(invest).subtract(debts));
        return out;
    }

    // ---------------- budgets ----------------
    @GetMapping("/budgets")
    public List<Map<String, Object>> budgets(@AuthenticationPrincipal Long uid,
            @RequestParam(required = false) String month) {
        String m = parseMonth(month).toString();
        return q(
                "SELECT b.id, c.name AS category, b.month, b.limit_amount, coalesce((SELECT sum(t.amount) FROM transactions t "
                        +
                        "WHERE t.user_id=b.user_id AND t.category_id=b.category_id AND t.type='EXPENSE' AND t.deleted_at IS NULL "
                        +
                        "AND to_char(t.txn_date,'YYYY-MM')=b.month),0) AS spent FROM budgets b JOIN categories c ON c.id=b.category_id "
                        +
                        "WHERE b.user_id=? AND b.month=? AND b.deleted_at IS NULL ORDER BY c.name",
                uid, m);
    }

    @PostMapping("/budgets")
    @ResponseStatus(HttpStatus.CREATED)
    public Map<String, Object> setBudget(@AuthenticationPrincipal Long uid, @Valid @RequestBody BudgetReq r) {
        parseMonth(r.month());
        one("SELECT id FROM categories WHERE id=? AND (user_id IS NULL OR user_id=?)", "Category not found",
                r.categoryId(), uid);
        Long id = jdbc.queryForObject("INSERT INTO budgets(user_id,category_id,month,limit_amount) VALUES (?,?,?,?) " +
                "ON CONFLICT (user_id,category_id,month) DO UPDATE SET limit_amount=EXCLUDED.limit_amount, deleted_at=NULL RETURNING id",
                Long.class, uid, r.categoryId(), r.month(), r.limitAmount());
        return Map.of("id", id);
    }

    @DeleteMapping("/budgets/{id}")
    public Map<String, String> deleteBudget(@AuthenticationPrincipal Long uid, @PathVariable long id) {
        if (jdbc.update("UPDATE budgets SET deleted_at=now() WHERE id=? AND user_id=? AND deleted_at IS NULL", id,
                uid) == 0)
            throw new ApiException(HttpStatus.NOT_FOUND, "Budget not found");
        return Map.of("status", "deleted");
    }

    // ---------------- goals ----------------
    @GetMapping("/goals")
    public List<Map<String, Object>> goals(@AuthenticationPrincipal Long uid) {
        return q(
                "SELECT id, name, target_amount, saved_amount, deadline FROM goals WHERE user_id=? AND deleted_at IS NULL ORDER BY deadline",
                uid);
    }

    @PostMapping("/goals")
    @ResponseStatus(HttpStatus.CREATED)
    public Map<String, Object> addGoal(@AuthenticationPrincipal Long uid, @Valid @RequestBody GoalReq r) {
        Long id = jdbc.queryForObject(
                "INSERT INTO goals(user_id,name,target_amount,deadline) VALUES (?,?,?,?) RETURNING id",
                Long.class, uid, r.name(), r.targetAmount(), r.deadline());
        return Map.of("id", id);
    }

    @PostMapping("/goals/{id}/contribute")
    public Map<String, String> contribute(@AuthenticationPrincipal Long uid, @PathVariable long id,
            @Valid @RequestBody AmountReq r) {
        if (jdbc.update(
                "UPDATE goals SET saved_amount=saved_amount+?, updated_at=now() WHERE id=? AND user_id=? AND deleted_at IS NULL",
                r.amount(), id, uid) == 0)
            throw new ApiException(HttpStatus.NOT_FOUND, "Goal not found");
        return Map.of("status", "ok");
    }

    // ---------------- debts ----------------
    @GetMapping("/debts")
    public List<Map<String, Object>> debts(@AuthenticationPrincipal Long uid) {
        return q(
                "SELECT id, name, principal, remaining, interest_rate, due_date FROM debts WHERE user_id=? AND deleted_at IS NULL ORDER BY id",
                uid);
    }

    @PostMapping("/debts")
    @ResponseStatus(HttpStatus.CREATED)
    public Map<String, Object> addDebt(@AuthenticationPrincipal Long uid, @Valid @RequestBody DebtReq r) {
        Long id = jdbc.queryForObject(
                "INSERT INTO debts(user_id,name,principal,remaining,interest_rate,due_date) VALUES (?,?,?,?,?,?) RETURNING id",
                Long.class, uid, r.name(), r.principal(), r.principal(), r.interestRate(), r.dueDate());
        return Map.of("id", id);
    }

    @PostMapping("/debts/{id}/pay")
    public Map<String, String> payDebt(@AuthenticationPrincipal Long uid, @PathVariable long id,
            @Valid @RequestBody AmountReq r) {
        if (jdbc.update(
                "UPDATE debts SET remaining=GREATEST(remaining-?,0), updated_at=now() WHERE id=? AND user_id=? AND deleted_at IS NULL",
                r.amount(), id, uid) == 0)
            throw new ApiException(HttpStatus.NOT_FOUND, "Debt not found");
        return Map.of("status", "ok");
    }

    // ---------------- investment simulator ----------------
    @GetMapping("/investments/assets")
    public List<Map<String, Object>> assets() {
        return q("SELECT id, symbol, name, asset_type, price, risk_level FROM assets ORDER BY asset_type, symbol");
    }

    private BigDecimal portfolioTotal(long uid) {
        BigDecimal cash = sum("SELECT coalesce(sum(cash),0) FROM portfolios WHERE user_id=?", uid);
        BigDecimal held = sum(
                "SELECT coalesce(sum(h.quantity*a.price),0) FROM portfolio_holdings h JOIN portfolios p ON p.id=h.portfolio_id "
                        +
                        "JOIN assets a ON a.id=h.asset_id WHERE p.user_id=?",
                uid);
        return cash.add(held).setScale(2, RoundingMode.HALF_UP);
    }

    @GetMapping("/investments/portfolio")
    public Map<String, Object> portfolio(@AuthenticationPrincipal Long uid) {
        List<Map<String, Object>> holdings = q(
                "SELECT a.id AS asset_id, a.symbol, a.name, a.asset_type, h.quantity, h.avg_price, a.price, " +
                        "round(h.quantity*a.price,2) AS value, round((a.price-h.avg_price)*h.quantity,2) AS profit FROM portfolio_holdings h "
                        +
                        "JOIN portfolios p ON p.id=h.portfolio_id JOIN assets a ON a.id=h.asset_id WHERE p.user_id=? AND h.quantity>0 ORDER BY a.symbol",
                uid);
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("cash", sum("SELECT coalesce(sum(cash),0) FROM portfolios WHERE user_id=?", uid));
        out.put("holdings", holdings);
        out.put("total", portfolioTotal(uid));
        return out;
    }

    @GetMapping("/investments/performance")
    public Map<String, Object> performance(@AuthenticationPrincipal Long uid, @RequestParam(defaultValue = "3M") String range) {
        return perf.history(uid, range);
    }

    @PostMapping("/investments/trade")
    @Transactional
    public Map<String, Object> trade(@AuthenticationPrincipal Long uid, @Valid @RequestBody TradeReq r) {
        Map<String, Object> pf = one("SELECT id, cash FROM portfolios WHERE user_id=? FOR UPDATE",
                "Portfolio not found", uid);
        Map<String, Object> asset = one("SELECT price FROM assets WHERE id=?", "Asset not found", r.assetId());
        long pid = ((Number) pf.get("id")).longValue();
        BigDecimal price = (BigDecimal) asset.get("price");
        BigDecimal value = price.multiply(r.quantity()).setScale(2, RoundingMode.HALF_UP);
        if (r.side().equals("BUY")) {
            if (value.compareTo((BigDecimal) pf.get("cash")) > 0)
                throw new ApiException(HttpStatus.BAD_REQUEST, "Not enough simulated cash");
            jdbc.update("UPDATE portfolios SET cash=cash-? WHERE id=?", value, pid);
            jdbc.update("INSERT INTO portfolio_holdings(portfolio_id,asset_id,quantity,avg_price) VALUES (?,?,?,?) " +
                    "ON CONFLICT (portfolio_id,asset_id) DO UPDATE SET " +
                    "avg_price=(portfolio_holdings.avg_price*portfolio_holdings.quantity+EXCLUDED.avg_price*EXCLUDED.quantity)/(portfolio_holdings.quantity+EXCLUDED.quantity), "
                    +
                    "quantity=portfolio_holdings.quantity+EXCLUDED.quantity", pid, r.assetId(), r.quantity(), price);
        } else {
            int n = jdbc.update(
                    "UPDATE portfolio_holdings SET quantity=quantity-? WHERE portfolio_id=? AND asset_id=? AND quantity>=?",
                    r.quantity(), pid, r.assetId(), r.quantity());
            if (n == 0)
                throw new ApiException(HttpStatus.BAD_REQUEST, "Not enough units to sell");
            jdbc.update("UPDATE portfolios SET cash=cash+? WHERE id=?", value, pid);
        }
        perf.snapshot(uid);
        audit.log(uid, "TRADE_" + r.side(), "asset=" + r.assetId() + " qty=" + r.quantity());
        return Map.of("status", "ok", "value", value);
    }

    @GetMapping("/investments/suggestion")
    public Map<String, Object> suggestion(@RequestParam(defaultValue = "3") int risk) {
        Map<String, Object> res = ai.post("/allocation", Map.of("risk_tolerance", risk));
        if (res == null)
            throw new ApiException(HttpStatus.SERVICE_UNAVAILABLE, "AI service unavailable");
        return res;
    }

    // ---------------- AI ----------------
    @PostMapping("/ai/advisor")
    public Map<String, Object> advisor(@AuthenticationPrincipal Long uid, @Valid @RequestBody AdvisorReq r) {
        String f = "FROM transactions WHERE user_id=? AND deleted_at IS NULL AND txn_date >= CURRENT_DATE - 90 ";
        BigDecimal three = new BigDecimal("3");
        BigDecimal income = sum("SELECT coalesce(sum(amount),0) " + f + "AND type='INCOME'", uid).divide(three, 2,
                RoundingMode.HALF_UP);
        BigDecimal expense = sum("SELECT coalesce(sum(amount),0) " + f + "AND type='EXPENSE'", uid).divide(three, 2,
                RoundingMode.HALF_UP);
        Map<String, Object> byCat = new LinkedHashMap<>();
        for (Map<String, Object> row : q(
                "SELECT coalesce(c.name,'Other') AS category, sum(t.amount)/3 AS total FROM transactions t " +
                        "LEFT JOIN categories c ON c.id=t.category_id WHERE t.user_id=? AND t.deleted_at IS NULL AND t.type='EXPENSE' "
                        +
                        "AND t.txn_date >= CURRENT_DATE - 90 GROUP BY c.name",
                uid)) {
            byCat.put((String) row.get("category"), ((BigDecimal) row.get("total")).setScale(2, RoundingMode.HALF_UP));
        }
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("goal_amount", r.goalAmount());
        body.put("months", r.months());
        body.put("saved_so_far", r.savedSoFar() == null ? BigDecimal.ZERO : r.savedSoFar());
        body.put("avg_income", income);
        body.put("avg_expense", expense);
        body.put("expense_by_category", byCat);
        Map<String, Object> res = ai.post("/advisor", body);
        if (res == null)
            throw new ApiException(HttpStatus.SERVICE_UNAVAILABLE, "AI service unavailable");
        Map<String, Object> out = new LinkedHashMap<>(res);
        out.put("avgIncome", income);
        out.put("avgExpense", expense);
        return out;
    }

    @PostMapping("/ai/chat")
    public Map<String, Object> chat(@AuthenticationPrincipal Long uid, @Valid @RequestBody ChatReq r) {
        YearMonth ym = YearMonth.now();
        Map<String, Object> s = monthSummary(uid, ym);
        Map<String, Object> byCat = new LinkedHashMap<>();
        for (Map<String, Object> row : (List<Map<String, Object>>) s.get("byCategory"))
            byCat.put((String) row.get("category"), row.get("total"));
        List<Map<String, Object>> b = budgets(uid, ym.toString()).stream().map(x -> Map.of(
                "category", x.get("category"), "limit", x.get("limit_amount"), "spent", x.get("spent"))).toList();
        Map<String, Object> ctx = new LinkedHashMap<>();
        ctx.put("month", ym.toString());
        ctx.put("income", s.get("income"));
        ctx.put("expense", s.get("expense"));
        ctx.put("by_category", byCat);
        ctx.put("budgets", b);
        Map<String, Object> res = ai.post("/chat", Map.of("message", r.message(), "context", ctx));
        if (res == null)
            throw new ApiException(HttpStatus.SERVICE_UNAVAILABLE, "AI service unavailable");
        return res;
    }

    @GetMapping("/recommendations")
    public List<Map<String, Object>> recommendations(@AuthenticationPrincipal Long uid) {
        return q(
                "SELECT id, kind, message, created_at FROM recommendations WHERE user_id=? ORDER BY created_at DESC LIMIT 20",
                uid);
    }

    // ---------------- admin ----------------
    @GetMapping("/admin/audit-logs")
    public List<Map<String, Object>> auditLogs() {
        return q("SELECT id, user_id, action, detail, created_at FROM audit_logs ORDER BY id DESC LIMIT 200");
    }
}
