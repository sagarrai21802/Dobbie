from datetime import datetime, timezone
from io import BytesIO
from typing import Any, Dict

import pdfplumber

from app.services.gemini_service import gemini_service


class ProfileService:
    MAX_PDF_SIZE_BYTES = 5 * 1024 * 1024

    @staticmethod
    def _normalize_profile_payload(payload: Dict[str, Any]) -> Dict[str, Any]:
        skills = payload.get("skills") or []
        if isinstance(skills, str):
            skills = [item.strip() for item in skills.split(",") if item.strip()]
        if not isinstance(skills, list):
            skills = []

        tone = str(payload.get("preferred_tone", "conversational")).strip().lower()
        if tone not in {"professional", "conversational", "inspirational", "technical"}:
            tone = "conversational"

        def _clean_str(key: str) -> str:
            return str(payload.get(key, "")).strip()

        years = payload.get("years_experience")
        years_normalized = years if isinstance(years, int) and years >= 0 else None

        is_complete = bool(
            _clean_str("name")
            and _clean_str("current_role")
            and _clean_str("industry")
            and len(skills) > 0
        )

        return {
            "name": _clean_str("name"),
            "headline": _clean_str("headline"),
            "location": _clean_str("location"),
            "current_role": _clean_str("current_role"),
            "industry": _clean_str("industry"),
            "skills": [str(item).strip() for item in skills if str(item).strip()][:20],
            "years_experience": years_normalized,
            "preferred_tone": tone,
            "is_complete": is_complete,
            "updated_at": datetime.now(timezone.utc),
        }

    @staticmethod
    def extract_text_from_pdf(file_bytes: bytes) -> str:
        with pdfplumber.open(BytesIO(file_bytes)) as pdf:
            text_parts = []
            for page in pdf.pages:
                page_text = page.extract_text() or ""
                if page_text.strip():
                    text_parts.append(page_text)
        return "\n\n".join(text_parts).strip()

    @staticmethod
    async def extract_profile_from_pdf(file_bytes: bytes) -> Dict[str, Any]:
        extracted_text = ProfileService.extract_text_from_pdf(file_bytes)
        if not extracted_text:
            raise ValueError("Could not extract readable text from PDF")
        extracted = gemini_service.extract_profile_from_linkedin_pdf_text(extracted_text)
        return ProfileService._normalize_profile_payload(extracted)

    @staticmethod
    async def save_profile(db, user_id, payload: Dict[str, Any]) -> Dict[str, Any]:
        profile = ProfileService._normalize_profile_payload(payload)
        await db.users.update_one(
            {"_id": user_id},
            {
                "$set": {
                    "profile": profile,
                    "updated_at": datetime.now(timezone.utc),
                }
            },
        )
        return profile

    @staticmethod
    def get_profile_from_user(user: Dict[str, Any]) -> Dict[str, Any]:
        profile = user.get("profile") or {}
        return ProfileService._normalize_profile_payload(profile)
