import httpx
from urllib.parse import urlencode
from app.config import settings


class LinkedInService:
    def __init__(self):
        self.client_id = settings.LINKEDIN_CLIENT_ID
        self.client_secret = settings.LINKEDIN_CLIENT_SECRET
        self.redirect_url = settings.LINKEDIN_REDIRECT_URL
        self.scope = "openid profile w_member_social"
        
    def get_authorization_url(self, state: str = "random_state") -> str:
        params = {
            "response_type": "code",
            "client_id": self.client_id,
            "redirect_uri": self.redirect_url,
            "scope": self.scope,
            "state": state,
        }
        return f"https://www.linkedin.com/oauth/v2/authorization?{urlencode(params)}"

    async def exchange_code_for_token(self, code: str) -> dict:
        async with httpx.AsyncClient() as client:
            response = await client.post(
                "https://www.linkedin.com/oauth/v2/accessToken",
                data={
                    "grant_type": "authorization_code",
                    "code": code,
                    "redirect_uri": self.redirect_url,
                    "client_id": self.client_id,
                    "client_secret": self.client_secret,
                },
                headers={"Content-Type": "application/x-www-form-urlencoded"},
            )
            if response.status_code != 200:
                raise Exception(f"Failed to exchange code: {response.text}")
            return response.json()

    async def get_user_profile(self, access_token: str) -> dict:
        async with httpx.AsyncClient() as client:
            response = await client.get(
                "https://api.linkedin.com/v2/userinfo",
                headers={"Authorization": f"Bearer {access_token}"},
            )
            if response.status_code != 200:
                raise Exception(f"Failed to get user profile: {response.text}")
            return response.json()

    async def create_post(self, access_token: str, content: str) -> dict:
        async with httpx.AsyncClient() as client:
            post_data = {
                "author": "urn:li:person:ME",
                "lifecycleState": "PUBLISHED",
                "specificContent": {
                    "com.linkedin.ugc.ShareContent": {
                        "shareCommentary": {"text": content},
                        "shareMediaCategory": "NONE",
                    }
                },
                "visibility": {
                    "com.linkedin.ugc.MemberNetworkVisibility": "PUBLIC"
                },
            }
            response = await client.post(
                "https://api.linkedin.com/v2/ugcPosts",
                json=post_data,
                headers={
                    "Authorization": f"Bearer {access_token}",
                    "Content-Type": "application/json",
                    "X-Restli-Protocol-Version": "2.0.0",
                },
            )
            if response.status_code != 201:
                raise Exception(f"Failed to create post: {response.text}")
            return response.json()


linkedin_service = LinkedInService()
