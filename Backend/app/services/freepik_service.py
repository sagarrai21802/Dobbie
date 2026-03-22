import asyncio
from typing import Optional

import httpx

from app.config import settings


class FreepikServiceError(Exception):
    pass


class FreepikConfigurationError(FreepikServiceError):
    pass


class FreepikRateLimitError(FreepikServiceError):
    pass


class FreepikTimeoutError(FreepikServiceError):
    pass


class FreepikTaskFailedError(FreepikServiceError):
    pass


class FreepikService:
    def __init__(self):
        self.api_key = settings.FREEPIK_API_KEY
        self.base_url = settings.FREEPIK_BASE_URL.rstrip("/")
        self.default_interval = settings.FREEPIK_MYSTIC_POLL_INTERVAL_SECONDS
        self.default_max_attempts = settings.FREEPIK_MYSTIC_MAX_ATTEMPTS

    def _ensure_config(self) -> None:
        if not self.api_key:
            raise FreepikConfigurationError("FREEPIK_API_KEY is not configured")

    def _headers(self) -> dict:
        return {
            "x-freepik-api-key": self.api_key,
            "Content-Type": "application/json",
            "Accept": "application/json",
        }

    def _build_prompt_from_content(self, content: str) -> str:
        # Use the generated post content directly as prompt context for image generation.
        normalized = " ".join((content or "").split())
        if not normalized:
            normalized = "LinkedIn post cover image"
        return normalized

    async def create_mystic_task(self, prompt: str, aspect_ratio: str = "widescreen_16_9") -> str:
        self._ensure_config()
        payload = {
            "prompt": prompt,
            "aspect_ratio": aspect_ratio,
        }

        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.post(
                f"{self.base_url}/v1/ai/mystic",
                json=payload,
                headers=self._headers(),
            )

        if response.status_code == 429:
            raise FreepikRateLimitError("Freepik rate limit or quota exceeded")
        if response.status_code >= 400:
            raise FreepikServiceError(f"Freepik task creation failed: {response.text}")

        body = response.json()
        task_id = body.get("data", {}).get("task_id")
        if not task_id:
            raise FreepikServiceError("Freepik response missing task_id")
        return task_id

    async def poll_mystic_result(
        self,
        task_id: str,
        max_attempts: Optional[int] = None,
        interval: Optional[int] = None,
    ) -> Optional[str]:
        self._ensure_config()

        attempts = max_attempts or self.default_max_attempts
        wait_seconds = interval or self.default_interval

        async with httpx.AsyncClient(timeout=30.0) as client:
            for _ in range(attempts):
                response = await client.get(
                    f"{self.base_url}/v1/ai/mystic/{task_id}",
                    headers=self._headers(),
                )

                if response.status_code == 429:
                    raise FreepikRateLimitError("Freepik rate limit or quota exceeded")
                if response.status_code >= 400:
                    raise FreepikServiceError(
                        f"Freepik task polling failed: {response.text}"
                    )

                data = response.json().get("data", {})
                status = str(data.get("status", "")).upper()

                if status == "COMPLETED":
                    generated = data.get("generated") or []
                    return generated[0] if generated else None

                if status in {"FAILED", "FAILURE"}:
                    raise FreepikTaskFailedError("Freepik image generation failed")

                await asyncio.sleep(wait_seconds)

        raise FreepikTimeoutError("Freepik image generation timed out")

    async def generate_image_from_post_text(self, content: str) -> Optional[str]:
        prompt = self._build_prompt_from_content(content)
        task_id = await self.create_mystic_task(prompt=prompt)
        return await self.poll_mystic_result(task_id=task_id)


freepik_service = FreepikService()
