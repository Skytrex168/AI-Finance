package com.finance.app.service;

import com.finance.app.web.ApiException;
import jakarta.annotation.PostConstruct;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.sql.Timestamp;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Random;

/**
 * Simulated market + portfolio value history for the Portfolio Performance chart.
 * Prices follow a small random walk (educational simulation, not real market data).
 * A snapshot of every portfolio value is stored each minute and after every trade.
 */
@Service
public class PerformanceService {
    private static final Logger log = LoggerFactory.getLogger(PerformanceService.class);

    private static final Map<String, Double> BASE = Map.of(
            "TECH", 182.40, "BANK", 54.10, "IDXF", 102.75, "GOVB", 99.80, "BTC", 64000.0, "ETH", 3200.0);

    private static final String VALUE_EXPR =
            "round(p.cash + coalesce((SELECT sum(h.quantity*a.price) FROM portfolio_holdings h " +
            "JOIN assets a ON a.id=h.asset_id WHERE h.portfolio_id=p.id),0),2)";

    private final JdbcTemplate jdbc;
    private final Random rnd = new Random();

    public PerformanceService(JdbcTemplate jdbc) { this.jdbc = jdbc; }

    @PostConstruct
    void createTable() {
        jdbc.execute("CREATE TABLE IF NOT EXISTS portfolio_snapshots (" +
                "id BIGSERIAL PRIMARY KEY, " +
                "user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE, " +
                "taken_at TIMESTAMPTZ NOT NULL DEFAULT now(), " +
                "total_value NUMERIC(14,2) NOT NULL)");
        jdbc.execute("CREATE INDEX IF NOT EXISTS idx_snap_user_time ON portfolio_snapshots(user_id, taken_at)");
    }

    // ---------------- scheduled simulation ----------------
    @Scheduled(initialDelay = 20_000, fixedRate = 60_000)
    public void tick() {
        try {
            ensureDemoHoldings();
            ensureDemoHistory();
            moveMarket();
            jdbc.update("INSERT INTO portfolio_snapshots(user_id, total_value) SELECT p.user_id, " + VALUE_EXPR + " FROM portfolios p");
            jdbc.update("DELETE FROM portfolio_snapshots WHERE taken_at < now() - interval '3 days' AND date_part('minute', taken_at) <> 0");
            jdbc.update("DELETE FROM portfolio_snapshots WHERE taken_at < now() - interval '400 days'");
        } catch (Exception e) {
            log.warn("Market tick failed: {}", e.getMessage());
        }
    }

    private void moveMarket() {
        for (Map<String, Object> a : jdbc.queryForList("SELECT id, symbol, price, risk_level FROM assets")) {
            double price = ((BigDecimal) a.get("price")).doubleValue();
            double base = BASE.getOrDefault((String) a.get("symbol"), price);
            int risk = ((Number) a.get("risk_level")).intValue();
            double vol = 0.0004 * risk;
            double next = price * (1 + rnd.nextGaussian() * vol + 0.002 * (base / price - 1));
            next = Math.max(next, base * 0.3);
            jdbc.update("UPDATE assets SET price=? WHERE id=?",
                    BigDecimal.valueOf(next).setScale(4, RoundingMode.HALF_UP), a.get("id"));
        }
    }

    // ---------------- demo data (demo@finance.app only) ----------------
    private void ensureDemoHoldings() {
        List<Long> ids = jdbc.queryForList(
                "SELECT p.id FROM portfolios p JOIN users u ON u.id=p.user_id WHERE u.email='demo@finance.app'", Long.class);
        if (ids.isEmpty()) return;
        long pid = ids.get(0);
        Integer n = jdbc.queryForObject("SELECT count(*) FROM portfolio_holdings WHERE portfolio_id=?", Integer.class, pid);
        BigDecimal cash = jdbc.queryForObject("SELECT cash FROM portfolios WHERE id=?", BigDecimal.class, pid);
        if ((n != null && n > 0) || cash == null || cash.compareTo(new BigDecimal("8000")) < 0) return;
        seedHolding(pid, "IDXF", 20, 0.95);
        seedHolding(pid, "TECH", 5, 0.95);
        seedHolding(pid, "GOVB", 30, 1.00);
        seedHolding(pid, "BTC", 0.03, 0.95);
    }

    private void seedHolding(long pid, String symbol, double qty, double costFactor) {
        jdbc.update("INSERT INTO portfolio_holdings(portfolio_id, asset_id, quantity, avg_price) " +
                        "SELECT ?, id, ?, round(price*?, 4) FROM assets WHERE symbol=?",
                pid, BigDecimal.valueOf(qty), BigDecimal.valueOf(costFactor), symbol);
        jdbc.update("UPDATE portfolios SET cash = cash - (SELECT round(h.quantity*h.avg_price, 2) " +
                        "FROM portfolio_holdings h JOIN assets a ON a.id=h.asset_id WHERE h.portfolio_id=? AND a.symbol=?) WHERE id=?",
                pid, symbol, pid);
    }

    private void ensureDemoHistory() {
        List<Long> users = jdbc.queryForList("SELECT id FROM users WHERE email='demo@finance.app'", Long.class);
        if (users.isEmpty()) return;
        long uid = users.get(0);
        Integer have = jdbc.queryForObject("SELECT count(*) FROM portfolio_snapshots WHERE user_id=?", Integer.class, uid);
        if (have != null && have > 0) return;
        List<BigDecimal> cur = jdbc.queryForList("SELECT " + VALUE_EXPR + " FROM portfolios p WHERE p.user_id=?", BigDecimal.class, uid);
        if (cur.isEmpty() || cur.get(0) == null) return;

        OffsetDateTime now = OffsetDateTime.now(ZoneOffset.UTC).truncatedTo(ChronoUnit.HOURS);
        List<Object[]> rows = new ArrayList<>();
        double v = cur.get(0).doubleValue();
        for (int h = 1; h <= 48; h++) {                         // hourly points for the last 2 days
            v = Math.max(1, v / (1 + rnd.nextGaussian() * 0.002 + 0.00005));
            rows.add(new Object[]{uid, now.minusHours(h), BigDecimal.valueOf(v).setScale(2, RoundingMode.HALF_UP)});
        }
        for (int d = 3; d <= 365; d++) {                        // daily points for the last year
            v = Math.max(1, v / (1 + rnd.nextGaussian() * 0.009 + 0.0006));
            rows.add(new Object[]{uid, now.minusDays(d), BigDecimal.valueOf(v).setScale(2, RoundingMode.HALF_UP)});
        }
        jdbc.batchUpdate("INSERT INTO portfolio_snapshots(user_id, taken_at, total_value) VALUES (?,?,?)", rows);
        log.info("Demo portfolio history generated ({} points)", rows.size());
    }

    // ---------------- API helpers ----------------
    public void snapshot(long userId) {
        jdbc.update("INSERT INTO portfolio_snapshots(user_id, total_value) SELECT p.user_id, " + VALUE_EXPR +
                " FROM portfolios p WHERE p.user_id=?", userId);
    }

    public Map<String, Object> history(long userId, String rangeRaw) {
        String range = rangeRaw == null ? "3M" : rangeRaw.toUpperCase();
        OffsetDateTime now = OffsetDateTime.now(ZoneOffset.UTC);
        OffsetDateTime from;
        switch (range) {
            case "1D": from = now.minusDays(1); break;
            case "2D": from = now.minusDays(2); break;
            case "1M": from = now.minusMonths(1); break;
            case "3M": from = now.minusMonths(3); break;
            case "YTD": from = OffsetDateTime.of(now.getYear(), 1, 1, 0, 0, 0, 0, ZoneOffset.UTC); break;
            case "1Y": from = now.minusYears(1); break;
            case "ALL": from = null; break;
            default: throw new ApiException(HttpStatus.BAD_REQUEST, "range must be 1D, 2D, 1M, 3M, YTD, 1Y or ALL");
        }
        List<Map<String, Object>> rows = from == null
                ? jdbc.queryForList("SELECT taken_at, total_value FROM portfolio_snapshots WHERE user_id=? ORDER BY taken_at", userId)
                : jdbc.queryForList("SELECT taken_at, total_value FROM portfolio_snapshots WHERE user_id=? AND taken_at>=? ORDER BY taken_at", userId, from);

        List<Map<String, Object>> points = new ArrayList<>();
        int n = rows.size();
        int step = Math.max(1, (int) Math.ceil(n / 120.0));
        for (int i = 0; i < n; i += step) points.add(point(rows.get(i)));
        if (n > 0 && (n - 1) % step != 0) points.add(point(rows.get(n - 1)));

        double start = n == 0 ? 0 : ((BigDecimal) rows.get(0).get("total_value")).doubleValue();
        double end = n == 0 ? 0 : ((BigDecimal) rows.get(n - 1).get("total_value")).doubleValue();
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("range", range);
        out.put("points", points);
        out.put("start", start);
        out.put("end", end);
        out.put("change", Math.round((end - start) * 100.0) / 100.0);
        out.put("changePct", start == 0 ? 0.0 : Math.round((end - start) / start * 10000.0) / 100.0);
        return out;
    }

    private Map<String, Object> point(Map<String, Object> r) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("t", ((Timestamp) r.get("taken_at")).toInstant().toString());
        m.put("v", r.get("total_value"));
        return m;
    }
}