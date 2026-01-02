package com.dobbie.oauth.service;

import com.dobbie.oauth.dto.TokenExchangeResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.*;
import org.springframework.stereotype.Service;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.util.MultiValueMap;
import org.springframework.web.client.RestTemplate;

import java.util.Map;

@Service
public class LinkedInService {

    private static final Logger logger = LoggerFactory.getLogger(LinkedInService.class);

    private static final String TOKEN_URL = "https://www.linkedin.com/oauth/v2/accessToken";
    private static final String USERINFO_URL = "https://api.linkedin.com/v2/userinfo";

    @Value("${linkedin.client-id}")
    private String clientId;

    @Value("${linkedin.client-secret}")
    private String clientSecret;

    private final RestTemplate restTemplate;

    public LinkedInService() {
        this.restTemplate = new RestTemplate();
    }

    /**
     * Exchange authorization code for access token and fetch member info
     */
    public TokenExchangeResponse exchangeCodeForToken(String code, String redirectUri) {
        logger.debug("Exchanging authorization code for token...");

        // Step 1: Exchange code for access token
        Map<String, Object> tokenResponse = getAccessToken(code, redirectUri);
        
        String accessToken = (String) tokenResponse.get("access_token");
        String refreshToken = (String) tokenResponse.getOrDefault("refresh_token", null);
        int expiresIn = (Integer) tokenResponse.getOrDefault("expires_in", 3600);

        logger.debug("✅ Got access token, expires in {} seconds", expiresIn);

        // Step 2: Fetch user info to get member ID
        Map<String, Object> userInfo = getUserInfo(accessToken);
        
        String memberId = (String) userInfo.get("sub");
        String memberUrn = "urn:li:person:" + memberId;

        logger.debug("✅ Got member URN: {}", memberUrn);

        return new TokenExchangeResponse(accessToken, refreshToken, expiresIn, memberId, memberUrn);
    }

    /**
     * Exchange authorization code for access token
     */
    @SuppressWarnings("unchecked")
    private Map<String, Object> getAccessToken(String code, String redirectUri) {
        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_FORM_URLENCODED);

        MultiValueMap<String, String> body = new LinkedMultiValueMap<>();
        body.add("grant_type", "authorization_code");
        body.add("code", code);
        body.add("redirect_uri", redirectUri);
        body.add("client_id", clientId);
        body.add("client_secret", clientSecret);

        HttpEntity<MultiValueMap<String, String>> request = new HttpEntity<>(body, headers);

        ResponseEntity<Map> response = restTemplate.postForEntity(TOKEN_URL, request, Map.class);
        
        if (!response.getStatusCode().is2xxSuccessful() || response.getBody() == null) {
            logger.error("❌ Failed to get access token: {}", response.getStatusCode());
            throw new RuntimeException("Failed to exchange code for token");
        }

        return response.getBody();
    }

    /**
     * Fetch user info using access token
     */
    @SuppressWarnings("unchecked")
    private Map<String, Object> getUserInfo(String accessToken) {
        HttpHeaders headers = new HttpHeaders();
        headers.setBearerAuth(accessToken);

        HttpEntity<Void> request = new HttpEntity<>(headers);

        ResponseEntity<Map> response = restTemplate.exchange(
            USERINFO_URL,
            HttpMethod.GET,
            request,
            Map.class
        );

        if (!response.getStatusCode().is2xxSuccessful() || response.getBody() == null) {
            logger.error("❌ Failed to get user info: {}", response.getStatusCode());
            throw new RuntimeException("Failed to fetch user info");
        }

        return response.getBody();
    }
}
