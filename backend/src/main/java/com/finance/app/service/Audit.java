package com.finance.app.service;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

@Service
public class Audit {
    private final JdbcTemplate jdbc;
    public Audit(JdbcTemplate jdbc) { this.jdbc = jdbc; }

    public void log(Long userId, String action, String detail) {
        jdbc.update("INSERT INTO audit_logs(user_id, action, detail) VALUES (?,?,?)", userId, action,
                detail == null ? null : detail.substring(0, Math.min(detail.length(), 500)));
    }
}
