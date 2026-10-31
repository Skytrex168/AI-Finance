package com.finance.app.service;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;

import java.util.Map;

/** Talks to the Python AI service. Every call degrades gracefully if the AI service is down. */
@Service
public class AiClient {
    private final RestClient http;

    public AiClient(@Value("${app.ai.url}") String url, @Value("${app.ai.key:}") String key) {
        var f = new SimpleClientHttpRequestFactory();
        f.setConnectTimeout(2000);
        f.setReadTimeout(25000);
        this.http = RestClient.builder().baseUrl(url).requestFactory(f)
                .defaultHeader("X-Internal-Key", key).build();
    }

    @SuppressWarnings("unchecked")
    public Map<String, Object> post(String path, Object body) {
        try {
            return http.post().uri(path).body(body).retrieve().body(Map.class);
        } catch (Exception e) {
            return null;
        }
    }
}
