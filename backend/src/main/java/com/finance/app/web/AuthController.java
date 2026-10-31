package com.finance.app.web;

import com.finance.app.security.JwtService;
import com.finance.app.service.Audit;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.dao.EmptyResultDataAccessException;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.web.bind.annotation.*;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.time.OffsetDateTime;
import java.util.Base64;
import java.util.HexFormat;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/auth")
public class AuthController {
    record RegisterReq(@NotBlank @Email String email, @NotBlank @Size(min = 8, max = 72) String password,
                       @NotBlank @Size(max = 120) String fullName) {}
    record LoginReq(@NotBlank String email, @NotBlank String password) {}
    record RefreshReq(@NotBlank String refreshToken) {}

    private final JdbcTemplate jdbc;
    private final PasswordEncoder encoder;
    private final JwtService jwt;
    private final Audit audit;
    private final long refreshDays;
    private final SecureRandom random = new SecureRandom();

    public AuthController(JdbcTemplate jdbc, PasswordEncoder encoder, JwtService jwt, Audit audit,
                          @Value("${app.jwt.refresh-days:14}") long refreshDays) {
        this.jdbc = jdbc; this.encoder = encoder; this.jwt = jwt; this.audit = audit; this.refreshDays = refreshDays;
    }

    @PostMapping("/register")
    @ResponseStatus(HttpStatus.CREATED)
    public Map<String, Object> register(@Valid @RequestBody RegisterReq r) {
        String email = r.email().trim().toLowerCase();
        Integer exists = jdbc.queryForObject("SELECT count(*) FROM users WHERE email=?", Integer.class, email);
        if (exists != null && exists > 0) throw new ApiException(HttpStatus.CONFLICT, "Email already registered");
        Long id = jdbc.queryForObject(
                "INSERT INTO users(role_id,email,password_hash,full_name) VALUES ((SELECT id FROM roles WHERE name='USER'),?,?,?) RETURNING id",
                Long.class, email, encoder.encode(r.password()), r.fullName().trim());
        jdbc.update("INSERT INTO accounts(user_id,name,type,balance) VALUES (?,?,?,0)", id, "Main Account", "BANK");
        jdbc.update("INSERT INTO portfolios(user_id) VALUES (?)", id);
        audit.log(id, "REGISTER", email);
        return tokens(id, "USER");
    }

    @PostMapping("/login")
    public Map<String, Object> login(@Valid @RequestBody LoginReq r) {
        String email = r.email().trim().toLowerCase();
        List<Map<String, Object>> rows = jdbc.queryForList(
                "SELECT u.id, u.password_hash, ro.name AS role FROM users u JOIN roles ro ON ro.id=u.role_id WHERE u.email=? AND u.deleted_at IS NULL", email);
        if (rows.isEmpty() || !encoder.matches(r.password(), (String) rows.get(0).get("password_hash"))) {
            audit.log(null, "LOGIN_FAILED", email);
            throw new ApiException(HttpStatus.UNAUTHORIZED, "Invalid credentials");
        }
        long id = ((Number) rows.get(0).get("id")).longValue();
        audit.log(id, "LOGIN", null);
        return tokens(id, (String) rows.get(0).get("role"));
    }

    @PostMapping("/refresh")
    public Map<String, Object> refresh(@Valid @RequestBody RefreshReq r) {
        String hash = sha256(r.refreshToken());
        Map<String, Object> row;
        try {
            row = jdbc.queryForMap("SELECT rt.id, rt.user_id, ro.name AS role FROM refresh_tokens rt " +
                    "JOIN users u ON u.id=rt.user_id JOIN roles ro ON ro.id=u.role_id " +
                    "WHERE rt.token_hash=? AND rt.revoked=false AND rt.expires_at>now() AND u.deleted_at IS NULL", hash);
        } catch (EmptyResultDataAccessException e) {
            throw new ApiException(HttpStatus.UNAUTHORIZED, "Invalid refresh token");
        }
        jdbc.update("UPDATE refresh_tokens SET revoked=true WHERE id=?", row.get("id"));   // rotation
        return tokens(((Number) row.get("user_id")).longValue(), (String) row.get("role"));
    }

    @PostMapping("/logout")
    public Map<String, String> logout(@Valid @RequestBody RefreshReq r) {
        jdbc.update("UPDATE refresh_tokens SET revoked=true WHERE token_hash=?", sha256(r.refreshToken()));
        return Map.of("status", "logged_out");
    }

    private Map<String, Object> tokens(long userId, String role) {
        byte[] raw = new byte[32];
        random.nextBytes(raw);
        String refresh = Base64.getUrlEncoder().withoutPadding().encodeToString(raw);
        jdbc.update("INSERT INTO refresh_tokens(user_id, token_hash, expires_at) VALUES (?,?,?)",
                userId, sha256(refresh), OffsetDateTime.now().plusDays(refreshDays));
        return Map.of("accessToken", jwt.createAccessToken(userId, role), "refreshToken", refresh, "role", role);
    }

    static String sha256(String s) {
        try {
            return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(s.getBytes(StandardCharsets.UTF_8)));
        } catch (Exception e) {
            throw new IllegalStateException(e);
        }
    }
}
