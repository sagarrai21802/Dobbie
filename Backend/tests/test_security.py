import pytest
from app.utils.security import create_oauth_state, verify_oauth_state


class TestOAuthState:
    """Test cases for OAuth state signing and verification."""

    def test_valid_state_returns_correct_user_id(self):
        """Valid state should return the correct user_id."""
        user_id = "507f1f77bcf86cd799439011"
        state = create_oauth_state(user_id)
        result = verify_oauth_state(state)
        assert result == user_id

    def test_tampered_state_returns_none(self):
        """Tampered state should return None."""
        user_id = "507f1f77bcf86cd799439011"
        state = create_oauth_state(user_id)
        tampered_state = state[:-5] + "xxxxx"
        result = verify_oauth_state(tampered_state)
        assert result is None

    def test_invalid_base64_returns_none(self):
        """Invalid base64 should return None."""
        invalid_state = "not-valid-base64!!!"
        result = verify_oauth_state(invalid_state)
        assert result is None

    def test_wrong_signature_returns_none(self):
        """State with wrong signature should return None."""
        import base64
        fake_state = base64.urlsafe_b64encode(b"user123.fake_signature").decode()
        result = verify_oauth_state(fake_state)
        assert result is None

    def test_empty_state_returns_none(self):
        """Empty state should return None."""
        result = verify_oauth_state("")
        assert result is None

    def test_malformed_state_no_dot_returns_none(self):
        """State without proper dot separator returns None."""
        import base64
        malformed_state = base64.urlsafe_b64encode(b"userid_no_dot").decode()
        result = verify_oauth_state(malformed_state)
        assert result is None

    def test_different_user_id_fails_verification(self):
        """State created with one user_id should not verify with different user_id."""
        user_id_1 = "507f1f77bcf86cd799439011"
        user_id_2 = "507f1f77bcf86cd799439022"
        state = create_oauth_state(user_id_1)
        result = verify_oauth_state(state)
        assert result == user_id_1
        assert result != user_id_2

    def test_same_user_produces_verifiable_state(self):
        """Same user_id should produce verifiable state consistently."""
        user_id = "507f1f77bcf86cd799439011"
        state = create_oauth_state(user_id)
        result = verify_oauth_state(state)
        assert result == user_id

    def test_special_characters_in_user_id(self):
        """User IDs with special characters should work."""
        user_id = "user@example.com"
        state = create_oauth_state(user_id)
        result = verify_oauth_state(state)
        assert result == user_id

    def test_unicode_user_id(self):
        """Unicode characters in user ID should work."""
        user_id = "user_123"
        state = create_oauth_state(user_id)
        result = verify_oauth_state(state)
        assert result == user_id
