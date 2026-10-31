package com.finance.app.security;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.concurrent.ConcurrentHashMap;

/** Simple in-memory limiter: 20 auth requests / minute / IP (use Redis for multi-instance deployments). */
@Component
public class RateLimitFilter extends OncePerRequestFilter {
    private record Window(long start, int count) {}
    private final ConcurrentHashMap<String, Window> windows = new ConcurrentHashMap<>();

    @Override
    protected boolean shouldNotFilter(HttpServletRequest req) {
        return !req.getRequestURI().startsWith("/api/auth/");
    }

    @Override
    protected void doFilterInternal(HttpServletRequest req, HttpServletResponse res, FilterChain chain)
            throws ServletException, IOException {
        long now = System.currentTimeMillis();
        Window w = windows.merge(req.getRemoteAddr(), new Window(now, 1),
                (old, fresh) -> now - old.start() > 60_000 ? fresh : new Window(old.start(), old.count() + 1));
        if (w.count() > 20) {
            res.setStatus(429);
            res.setContentType("application/json");
            res.getWriter().write("{\"error\":\"Too many requests\"}");
            return;
        }
        chain.doFilter(req, res);
    }
}
