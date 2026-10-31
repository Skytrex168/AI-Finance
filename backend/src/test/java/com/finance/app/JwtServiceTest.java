package com.finance.app;

import com.finance.app.security.JwtService;
import io.jsonwebtoken.JwtException;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

class JwtServiceTest {
    private static final String SECRET = "unit-test-secret-unit-test-secret-1234";

    @Test
    void createsAndParsesToken() {
        JwtService s = new JwtService(SECRET, 15);
        var claims = s.parse(s.createAccessToken(7, "USER"));
        assertEquals("7", claims.getSubject());
        assertEquals("USER", claims.get("role", String.class));
    }

    @Test
    void rejectsExpiredToken() {
        JwtService s = new JwtService(SECRET, -1);
        assertThrows(JwtException.class, () -> s.parse(s.createAccessToken(1, "USER")));
    }

    @Test
    void rejectsTamperedToken() {
        JwtService s = new JwtService(SECRET, 15);
        String t = s.createAccessToken(1, "USER");
        assertThrows(JwtException.class, () -> s.parse(t.substring(0, t.length() - 2) + "xx"));
    }

    @Test
    void rejectsShortSecret() {
        assertThrows(IllegalStateException.class, () -> new JwtService("short", 15));
    }
}
