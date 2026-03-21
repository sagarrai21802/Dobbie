package com.dobbie.oauth.controller;

import com.dobbie.oauth.dto.TokenExchangeRequest;
import com.dobbie.oauth.dto.TokenExchangeResponse;
import com.dobbie.oauth.service.LinkedInService;
import jakarta.validation.Valid;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.net.URI;
import java.util.Map;

@RestController
public class LinkedInController {

    private static final Logger logger = LoggerFactory.getLogger(LinkedInController.class);

    private final LinkedInService linkedInService;

    public LinkedInController(LinkedInService linkedInService) {
        this.linkedInService = linkedInService;
    }

    /**
     * Health check endpoint
     */
    @GetMapping("/health")
    public ResponseEntity<Map<String, String>> health() {
        return ResponseEntity.ok(Map.of("status", "ok"));
    }

    /**
     * LinkedIn OAuth callback - receives code from LinkedIn and redirects to iOS app
     * This is the redirect_uri registered with LinkedIn
     */
    @GetMapping("/linkedin")
    public ResponseEntity<Void> linkedInCallback(
            @RequestParam(required = false) String code,
            @RequestParam(required = false) String state,
            @RequestParam(required = false) String error,
            @RequestParam(name = "error_description", required = false) String errorDescription) {
        
        logger.info("📥 Received LinkedIn callback");
        
        if (error != null) {
            logger.error("❌ LinkedIn auth error: {} - {}", error, errorDescription);
            // Redirect to app with error
            String redirectUrl = "dobbie://linkedin/callback?error=" + error;
            return ResponseEntity.status(HttpStatus.FOUND)
                    .location(URI.create(redirectUrl))
                    .build();
        }
        
        if (code == null) {
            logger.error("❌ No authorization code received");
            return ResponseEntity.badRequest().build();
        }
        
        logger.info("✅ Received authorization code, redirecting to iOS app");
        
        // Redirect to iOS app with the authorization code
        String redirectUrl = "dobbie://linkedin/callback?code=" + code;
        if (state != null) {
            redirectUrl += "&state=" + state;
        }
        
        return ResponseEntity.status(HttpStatus.FOUND)
                .location(URI.create(redirectUrl))
                .build();
    }

    /**
     * Exchange LinkedIn authorization code for access token and member URN
     */
    @PostMapping("/linkedin/exchange")
    public ResponseEntity<?> exchangeToken(@Valid @RequestBody TokenExchangeRequest request) {
        logger.info("📥 Received token exchange request");
        
        try {
            TokenExchangeResponse response = linkedInService.exchangeCodeForToken(
                request.getCode(),
                request.getRedirect_uri()
            );
            
            logger.info("✅ Token exchange successful for member: {}", response.getMemberUrn());
            return ResponseEntity.ok(response);
            
        } catch (Exception e) {
            logger.error("❌ Token exchange failed: {}", e.getMessage());
            return ResponseEntity.badRequest().body(Map.of(
                "error", "token_exchange_failed",
                "message", e.getMessage()
            ));
        }
    }
}

