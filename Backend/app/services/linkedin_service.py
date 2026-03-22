import httpx
import logging
from urllib.parse import urlencode
from typing import Optional
from app.config import settings


logger = logging.getLogger(__name__)


class LinkedInAPIError(Exception):
    def __init__(self, message: str, status_code: int):
        super().__init__(message)
        self.status_code = status_code


class LinkedInService:
    def __init__(self):
        self.client_id = settings.LINKEDIN_CLIENT_ID
        self.client_secret = settings.LINKEDIN_CLIENT_SECRET
        self.redirect_url = settings.LINKEDIN_REDIRECT_URL
        self.scope = settings.LINKEDIN_SCOPE

    @staticmethod
    def _mask_token(token: Optional[str]) -> Optional[str]:
        if not token:
            return token
        return token[:8] + "..." if len(token) > 8 else token

    def _log_token_response(self, token_data: dict, source: str) -> None:
        safe_log = {
            "access_token": self._mask_token(token_data.get("access_token")),
            "refresh_token": self._mask_token(token_data.get("refresh_token")),
            "expires_in": token_data.get("expires_in"),
            "refresh_token_expires_in": token_data.get("refresh_token_expires_in"),
            "scope": token_data.get("scope"),
        }
        logger.info("LinkedIn token response (%s, masked): %s", source, safe_log)
        
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
            token_data = response.json()
            self._log_token_response(token_data, "authorization_code")
            return token_data

    async def refresh_access_token(self, refresh_token: str) -> dict:
        async with httpx.AsyncClient() as client:
            response = await client.post(
                "https://www.linkedin.com/oauth/v2/accessToken",
                data={
                    "grant_type": "refresh_token",
                    "refresh_token": refresh_token,
                    "client_id": self.client_id,
                    "client_secret": self.client_secret,
                },
                headers={"Content-Type": "application/x-www-form-urlencoded"},
            )

        if response.status_code != 200:
            raise LinkedInAPIError(
                message=f"Failed to refresh LinkedIn access token: {response.text}",
                status_code=response.status_code,
            )

        token_data = response.json()
        self._log_token_response(token_data, "refresh_token")
        if not token_data.get("access_token"):
            raise LinkedInAPIError(
                message="LinkedIn refresh response missing access_token",
                status_code=502,
            )

        return token_data

    async def get_user_profile(self, access_token: str) -> dict:
        async with httpx.AsyncClient() as client:
            response = await client.get(
                "https://api.linkedin.com/v2/userinfo",
                headers={"Authorization": f"Bearer {access_token}"},
            )
            if response.status_code != 200:
                raise Exception(f"Failed to get user profile: {response.text}")
            return response.json()

    @staticmethod
    def build_person_urn(linkedin_user_id: str) -> str:
        linkedin_user_id = (linkedin_user_id or "").strip()
        if linkedin_user_id.startswith("urn:li:person:"):
            return linkedin_user_id
        return f"urn:li:person:{linkedin_user_id}"

    async def _download_image_bytes(self, image_url: str) -> tuple[bytes, str]:
        async with httpx.AsyncClient() as client:
            response = await client.get(image_url)
            if response.status_code != 200:
                raise LinkedInAPIError(
                    message=f"Failed to download generated image: {response.text}",
                    status_code=response.status_code,
                )
            content_type = response.headers.get("Content-Type", "image/png")
            return response.content, content_type

    async def _register_image_upload(self, access_token: str, author_urn: str) -> tuple[str, str]:
        payload = {
            "registerUploadRequest": {
                "recipes": ["urn:li:digitalmediaRecipe:feedshare-image"],
                "owner": author_urn,
                "serviceRelationships": [
                    {
                        "relationshipType": "OWNER",
                        "identifier": "urn:li:userGeneratedContent",
                    }
                ],
            }
        }

        async with httpx.AsyncClient() as client:
            response = await client.post(
                "https://api.linkedin.com/v2/assets?action=registerUpload",
                json=payload,
                headers={
                    "Authorization": f"Bearer {access_token}",
                    "Content-Type": "application/json",
                    "X-Restli-Protocol-Version": "2.0.0",
                },
            )

        if response.status_code != 200:
            raise LinkedInAPIError(
                message=f"Failed to register LinkedIn image upload: {response.text}",
                status_code=response.status_code,
            )

        value = response.json().get("value", {})
        upload_url = (
            value.get("uploadMechanism", {})
            .get("com.linkedin.digitalmedia.uploading.MediaUploadHttpRequest", {})
            .get("uploadUrl")
        )
        asset_urn = value.get("asset")

        if not upload_url or not asset_urn:
            raise LinkedInAPIError(
                message="LinkedIn register upload response missing uploadUrl or asset URN",
                status_code=500,
            )

        return upload_url, asset_urn

    async def _upload_image_bytes(self, upload_url: str, image_bytes: bytes, content_type: str) -> None:
        async with httpx.AsyncClient() as client:
            response = await client.put(
                upload_url,
                content=image_bytes,
                headers={
                    "Content-Type": content_type,
                },
            )

        if response.status_code not in (200, 201):
            raise LinkedInAPIError(
                message=f"Failed to upload image to LinkedIn: {response.text}",
                status_code=response.status_code,
            )

    async def create_post(
        self,
        access_token: str,
        content: str,
        author_urn: str,
        image_url: Optional[str] = None,
    ) -> dict:
        media_asset_urn: Optional[str] = None

        if image_url:
            image_bytes, content_type = await self._download_image_bytes(image_url)
            upload_url, media_asset_urn = await self._register_image_upload(access_token, author_urn)
            await self._upload_image_bytes(upload_url, image_bytes, content_type)

        async with httpx.AsyncClient() as client:
            share_content = {
                "shareCommentary": {"text": content},
                "shareMediaCategory": "NONE",
            }

            if media_asset_urn:
                share_content = {
                    "shareCommentary": {"text": content},
                    "shareMediaCategory": "IMAGE",
                    "media": [
                        {
                            "status": "READY",
                            "description": {"text": "AI generated cover image"},
                            "media": media_asset_urn,
                            "title": {"text": "Post cover"},
                        }
                    ],
                }

            post_data = {
                "author": author_urn,
                "lifecycleState": "PUBLISHED",
                "specificContent": {
                    "com.linkedin.ugc.ShareContent": share_content
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
                raise LinkedInAPIError(
                    message=f"Failed to create post: {response.text}",
                    status_code=response.status_code,
                )
            return response.json()


linkedin_service = LinkedInService()
