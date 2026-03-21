package com.dobbie.oauth.dto;

import com.fasterxml.jackson.annotation.JsonProperty;

public class TokenExchangeResponse {
    
    @JsonProperty("access_token")
    private String accessToken;
    
    @JsonProperty("refresh_token")
    private String refreshToken;
    
    @JsonProperty("expires_in")
    private int expiresIn;
    
    @JsonProperty("member_id")
    private String memberId;
    
    @JsonProperty("member_urn")
    private String memberUrn;

    // Constructor
    public TokenExchangeResponse(String accessToken, String refreshToken, int expiresIn, 
                                  String memberId, String memberUrn) {
        this.accessToken = accessToken;
        this.refreshToken = refreshToken;
        this.expiresIn = expiresIn;
        this.memberId = memberId;
        this.memberUrn = memberUrn;
    }

    // Getters
    public String getAccessToken() {
        return accessToken;
    }

    public String getRefreshToken() {
        return refreshToken;
    }

    public int getExpiresIn() {
        return expiresIn;
    }

    public String getMemberId() {
        return memberId;
    }

    public String getMemberUrn() {
        return memberUrn;
    }
}
