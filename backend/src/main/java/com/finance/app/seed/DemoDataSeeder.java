package com.finance.app.seed;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.Map;
import java.util.Random;

/**
 * Creates demo/admin users and ~90 days of sample transactions (DEV ONLY: set
 * SEED_DEMO=false in production).
 */
@Component
public class DemoDataSeeder implements ApplicationRunner {
    private final JdbcTemplate jdbc;
    private final PasswordEncoder encoder;
    private final boolean enabled;

    public DemoDataSeeder(JdbcTemplate jdbc, PasswordEncoder encoder, @Value("${app.seed-demo:true}") boolean enabled) {
        this.jdbc = jdbc;
        this.encoder = encoder;
        this.enabled = enabled;
    }

    @Override
    public void run(ApplicationArguments args) {
        if (!enabled)
            return;
        Integer n = jdbc.queryForObject("SELECT count(*) FROM users WHERE email='demo@finance.app'", Integer.class);
        if (n != null && n > 0)
            return;

        long adminId = createUser("admin@finance.app", "Admin@1234", "Admin User", "ADMIN");
        long uid = createUser("demo@finance.app", "Demo@1234", "Demo User", "USER");
        jdbc.update("INSERT INTO accounts(user_id,name,type,balance) VALUES (?,?,?,0)", adminId, "Main Account",
                "BANK");
        jdbc.update("INSERT INTO portfolios(user_id) VALUES (?),(?)", adminId, uid);
        Long acc = jdbc.queryForObject("INSERT INTO accounts(user_id,name,type,balance) VALUES (?,?,?,0) RETURNING id",
                Long.class, uid, "ABA Bank", "BANK");

        Random rnd = new Random(42);
        String[][] spend = {
                { "Food", "Lunch at restaurant", "4", "9" }, { "Food", "Coffee at cafe", "2", "5" },
                { "Transport", "Grab ride", "2", "8" }, { "Shopping", "Lazada order", "15", "60" },
                { "Entertainment", "Netflix", "10", "15" }, { "Bills", "Internet wifi bill", "18", "22" },
                { "Health", "Pharmacy medicine", "5", "20" } };
        BigDecimal balance = BigDecimal.ZERO;
        LocalDate today = LocalDate.now();
        for (int d = 90; d >= 0; d--) {
            LocalDate date = today.minusDays(d);
            if (date.getDayOfMonth() == 1) {
                balance = balance.add(insert(uid, acc, "Salary", "INCOME", "1500", "Monthly salary", date));
            }
            for (String[] s : spend) {
                if (rnd.nextInt(100) < 35) {
                    double lo = Double.parseDouble(s[2]), hi = Double.parseDouble(s[3]);
                    String amt = String.format("%.2f", lo + rnd.nextDouble() * (hi - lo));
                    balance = balance.subtract(insert(uid, acc, s[0], "EXPENSE", amt, s[1], date));
                }
            }
        }
        // one deliberate outlier for the anomaly-detection demo
        balance = balance.subtract(insert(uid, acc, "Food", "EXPENSE", "250.00", "Dinner at restaurant", today));
        jdbc.update("UPDATE accounts SET balance=? WHERE id=?", balance.add(new BigDecimal("500")), acc);
        jdbc.update("INSERT INTO goals(user_id,name,target_amount,saved_amount,deadline) VALUES (?,?,?,?,?)",
                uid, "New laptop", 800, 150, today.plusMonths(6));
        jdbc.update("INSERT INTO debts(user_id,name,principal,remaining,interest_rate) VALUES (?,?,?,?,?)",
                uid, "Phone installment", 400, 250, 0);
        jdbc.update(
                "INSERT INTO budgets(user_id,category_id,month,limit_amount) VALUES (?,(SELECT id FROM categories WHERE name='Food' AND user_id IS NULL),?,?)",
                uid, today.toString().substring(0, 7), 120);
    }

    private long createUser(String email, String pass, String name, String role) {
        Long id = jdbc.queryForObject(
                "INSERT INTO users(role_id,email,password_hash,full_name) VALUES ((SELECT id FROM roles WHERE name=?),?,?,?) RETURNING id",
                Long.class, role, email, encoder.encode(pass), name);
        return id;
    }

    private BigDecimal insert(long uid, long acc, String cat, String type, String amount, String desc, LocalDate date) {
        jdbc.update(
                "INSERT INTO transactions(user_id,account_id,category_id,type,amount,description,txn_date) VALUES (?,?,(SELECT id FROM categories WHERE name=? AND user_id IS NULL),?,?,?,?)",
                uid, acc, cat, type, new BigDecimal(amount), desc, date);
        return new BigDecimal(amount);
    }
}
