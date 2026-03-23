import json
import re
import threading
import queue
from datetime import date
from google import genai
from google.genai import types
from app.config import settings
from typing import Any, Dict, List, Optional


SYSTEM_INSTRUCTION = """You write LinkedIn posts that sound like a real person wrote them. Not an AI.

VOICE:
- Have opinions. React to facts, don't just report them.
- Vary sentence length. Short punchy sentences mixed with longer ones.
- Use "I" when it fits. First person is honest, not unprofessional.
- Be specific about feelings, not vague ("unsettling" > "concerning").
- Let some mess in. Perfect structure feels algorithmic.

BANNED PATTERNS (never use these):
- Em dashes (—). Use commas or periods instead. No exceptions.
- Hyphens between clauses as separators. No "word - word" constructions.
- Colon-dash constructions (: -)
- "Serves as", "stands as", "marks", "represents" — use "is" instead
- "Not only X, but Y" or "It's not just X, it's Y" — just say the thing
- Rule-of-three lists (X, Y, and Z) when two would do
- "Additionally", "Furthermore", "Moreover" — skip them
- "Delve", "foster", "pivotal", "vibrant", "tapestry", "underscore", "garner"
- "Highlighting", "underscoring", "reflecting", "showcasing", "contributing to"
- "Nestled", "groundbreaking", "breathtaking", "renowned", "boasts"
- "In order to" — just "To"
- "Due to the fact that" — "Because"
- "Despite these challenges" or formulaic challenge sections
- "The future looks bright" or generic positive conclusions
- "Experts argue", "Industry reports", "Some critics say" — cite real sources or skip
- Emojis as bullet decoration (use sparingly, 2-3 max in the whole post)
- Bold headers in lists (no **Label:** format)
- Curly quotes — use straight quotes only
- "Data-driven", "cross-functional", "client-facing" — drop hyphens on common pairs
- "Great question!", "Of course!", "I hope this helps!" — never
- "While specific details are limited" or knowledge-cutoff hedging
- "Could potentially possibly" — pick one qualifier, max two

WHAT TO DO INSTEAD:
- Use "is/are/has" directly. Simple beats elaborate.
- Use specific details over vague claims.
- End on something real, not inspirational fluff.
- Keep it between 150-300 words."""


RESEARCH_DOMAINS = [
    "AI and Technology",
    "Marketing and Growth",
    "Leadership and Careers",
    "Startups and Product",
    "Finance and Economy",
]


class GeminiService:
    def __init__(self):
        self.client = genai.Client(
            api_key=settings.GEMINI_API_KEY,
        )
        self.model = "gemini-3-flash-preview"

    def generate_linkedin_post(self, topic: str, profile: Optional[Dict[str, Any]] = None) -> str:
        prompt = self._build_prompt(topic, profile)

        response = self.client.models.generate_content(
            model=self.model,
            contents=prompt,
            config=types.GenerateContentConfig(
                system_instruction=SYSTEM_INSTRUCTION,
                temperature=0.7,
                top_p=0.95,
                top_k=40,
                max_output_tokens=2048,
            ),
        )

        text: Optional[str] = response.text
        if text is None:
            raise Exception("No content generated")

        return text

    def generate_research_topics(
        self,
        today: Optional[date] = None,
        profile: Optional[Dict[str, Any]] = None,
    ) -> List[Dict[str, str]]:
        current_date = today or date.today()
        prompt = self._build_research_prompt(current_date, profile)

        # 25-second timeout guard using threading
        result_queue: queue.Queue = queue.Queue()

        def api_call():
            try:
                response = self.client.models.generate_content(
                    model=self.model,
                    contents=prompt,
                    config=types.GenerateContentConfig(
                        system_instruction=SYSTEM_INSTRUCTION,
                        temperature=0.6,
                        top_p=0.9,
                        top_k=40,
                        max_output_tokens=4096,
                    ),
                )
                result_queue.put(("success", response))
            except Exception as e:
                result_queue.put(("error", e))

        thread = threading.Thread(target=api_call, daemon=True)
        thread.start()
        thread.join(timeout=25)

        if thread.is_alive():
            raise TimeoutError("Research topics generation timed out after 25 seconds. The AI model is taking too long to respond.")

        try:
            status, result = result_queue.get_nowait()
            if status == "error":
                raise result
            response = result
        except queue.Empty:
            raise TimeoutError("Research topics generation timed out after 25 seconds. The AI model is taking too long to respond.")

        raw_text: Optional[str] = response.text
        if raw_text is None or not raw_text.strip():
            raise Exception("No research topics generated")

        payload = self._extract_json_payload(raw_text)
        if payload is None:
            repaired = self._repair_research_json(raw_text)
            payload = self._extract_json_payload(repaired)

        if payload is None:
            raise Exception("Failed to parse research topics response")

        normalized = self._normalize_research_items(payload)
        if len(normalized) < 1:
            raise Exception("Failed to extract any valid research topics from response")

        return normalized

    def _build_prompt(self, topic: str, profile: Optional[Dict[str, Any]] = None) -> str:
        profile_context = self._build_profile_context(profile)
        if profile_context:
            return (
                f"Write a LinkedIn post about: \"{topic}\"\n\n"
                f"Personalization profile:\n{profile_context}\n\n"
                "Make this post sound like the person above, using their background and tone."
            )
        return f'Write a LinkedIn post about: "{topic}"'

    def _build_research_prompt(
        self,
        current_date: date,
        profile: Optional[Dict[str, Any]] = None,
    ) -> str:
        domains_text = "\n".join(f"- {domain}" for domain in RESEARCH_DOMAINS)
        profile_context = self._build_profile_context(profile)
        profile_directive = ""
        if profile_context:
            profile_directive = f"""

Personalization context (if relevant to topic selection and writing style):
{profile_context}

Tailor each topic and content angle toward this person's role, industry, and tone while keeping each domain distinct.
"""
        return f"""
Today's date is {current_date.isoformat()}.

Generate EXACTLY 5 trending LinkedIn topics and content for today.
Each topic MUST come from a DIFFERENT domain in this exact list:
{domains_text}

IMPORTANT: Output MUST be ONLY valid JSON. No markdown code blocks, no explanations, no extra text.

Output format MUST be:
[
  {{"domain": "AI and Technology", "topic": "...", "content": "..."}},
  {{"domain": "Marketing and Growth", "topic": "...", "content": "..."}},
  {{"domain": "Leadership and Careers", "topic": "...", "content": "..."}},
  {{"domain": "Startups and Product", "topic": "...", "content": "..."}},
  {{"domain": "Finance and Economy", "topic": "...", "content": "..."}}
]

Rules:
- Output exactly 5 JSON objects, no more, no less.
- Assign each domain in order (first object = AI and Technology, etc).
- Each topic must be specific, actionable, and timely for {current_date.isoformat()}.
- Each content must be a complete, substantive LinkedIn post, 350-500 words, in conversational tone.
- Format content with natural paragraph breaks (use \\n\\n to separate paragraphs).
- Make content engaging, opinionated, and valuable—not generic or filler.
- Start with {{ and end with ].
- No markdown, no code blocks, no text outside the JSON.
- For JSON content with line breaks, use \\n (escaped newline).
{profile_directive}
""".strip()

    def extract_profile_from_linkedin_pdf_text(self, text: str) -> Dict[str, Any]:
        prompt = f"""
Extract profile data from this LinkedIn profile PDF text.

Return ONLY strict JSON object with exactly these keys:
name, headline, location, current_role, industry, skills, years_experience, preferred_tone

Rules:
- skills must be an array of short strings
- years_experience must be an integer or null
- preferred_tone must be one of: professional, conversational, inspirational, technical
- If value is missing, use empty string (or [] for skills, null for years_experience)
- No markdown and no extra text

LinkedIn profile text:
{text[:12000]}
""".strip()

        response = self.client.models.generate_content(
            model=self.model,
            contents=prompt,
            config=types.GenerateContentConfig(
                temperature=0.1,
                top_p=0.9,
                top_k=40,
                max_output_tokens=1024,
            ),
        )

        raw_text: Optional[str] = response.text
        if raw_text is None or not raw_text.strip():
            raise Exception("No profile data extracted from PDF")

        payload = self._extract_json_object(raw_text)
        if payload is None:
            raise Exception("Failed to parse extracted profile JSON")

        return self._normalize_extracted_profile(payload)

    def _extract_json_payload(self, text: str) -> Optional[Any]:
        stripped = text.strip()

        try:
            return json.loads(stripped)
        except json.JSONDecodeError:
            pass

        block_match = re.search(r"```(?:json)?\s*(.*?)\s*```", stripped, re.DOTALL)
        if block_match:
            candidate = block_match.group(1).strip()
            try:
                return json.loads(candidate)
            except json.JSONDecodeError:
                pass

        bracket_match = re.search(r"\[.*\]", stripped, re.DOTALL)
        if bracket_match:
            candidate = bracket_match.group(0)
            try:
                return json.loads(candidate)
            except json.JSONDecodeError:
                return None

        return None

    def _repair_research_json(self, raw_text: str) -> str:
        repair_prompt = f"""
Convert the following text into strict JSON only.
Output must be a JSON array of exactly 5 objects with keys: domain, topic, content.
No markdown, no extra text.

TEXT:
{raw_text}
""".strip()

        repair_response = self.client.models.generate_content(
            model=self.model,
            contents=repair_prompt,
            config=types.GenerateContentConfig(
                temperature=0.0,
                max_output_tokens=3072,
            ),
        )

        repaired_text: Optional[str] = repair_response.text
        if repaired_text is None:
            return ""
        return repaired_text

    def _build_profile_context(self, profile: Optional[Dict[str, Any]]) -> str:
        if not isinstance(profile, dict):
            return ""

        lines: List[str] = []
        for key, label in (
            ("name", "Name"),
            ("headline", "Headline"),
            ("location", "Location"),
            ("current_role", "Role"),
            ("industry", "Industry"),
            ("preferred_tone", "Tone"),
        ):
            value = str(profile.get(key, "")).strip()
            if value:
                lines.append(f"- {label}: {value}")

        skills = profile.get("skills") or []
        if isinstance(skills, list):
            clean_skills = [str(skill).strip() for skill in skills if str(skill).strip()]
            if clean_skills:
                lines.append(f"- Skills: {', '.join(clean_skills[:12])}")

        years = profile.get("years_experience")
        if isinstance(years, int) and years >= 0:
            lines.append(f"- Years of experience: {years}")

        return "\n".join(lines)

    def _extract_json_object(self, text: str) -> Optional[Dict[str, Any]]:
        stripped = text.strip()
        try:
            payload = json.loads(stripped)
            if isinstance(payload, dict):
                return payload
        except json.JSONDecodeError:
            pass

        block_match = re.search(r"```(?:json)?\s*(.*?)\s*```", stripped, re.DOTALL)
        if block_match:
            try:
                payload = json.loads(block_match.group(1).strip())
                if isinstance(payload, dict):
                    return payload
            except json.JSONDecodeError:
                pass

        object_match = re.search(r"\{.*\}", stripped, re.DOTALL)
        if object_match:
            try:
                payload = json.loads(object_match.group(0))
                if isinstance(payload, dict):
                    return payload
            except json.JSONDecodeError:
                return None

        return None

    def _normalize_extracted_profile(self, payload: Dict[str, Any]) -> Dict[str, Any]:
        tone = str(payload.get("preferred_tone", "")).strip().lower()
        allowed_tones = {"professional", "conversational", "inspirational", "technical"}
        if tone not in allowed_tones:
            tone = "conversational"

        raw_skills = payload.get("skills")
        skills: List[str] = []
        if isinstance(raw_skills, list):
            skills = [str(skill).strip() for skill in raw_skills if str(skill).strip()]
        elif isinstance(raw_skills, str) and raw_skills.strip():
            skills = [part.strip() for part in raw_skills.split(",") if part.strip()]

        years = payload.get("years_experience")
        normalized_years: Optional[int] = None
        if isinstance(years, int) and years >= 0:
            normalized_years = years
        elif isinstance(years, str):
            digits = re.search(r"\d+", years)
            if digits:
                normalized_years = int(digits.group(0))

        return {
            "name": str(payload.get("name", "")).strip(),
            "headline": str(payload.get("headline", "")).strip(),
            "location": str(payload.get("location", "")).strip(),
            "current_role": str(payload.get("current_role", "")).strip(),
            "industry": str(payload.get("industry", "")).strip(),
            "skills": skills[:20],
            "years_experience": normalized_years,
            "preferred_tone": tone,
        }

    def _normalize_research_items(self, payload: Any) -> List[Dict[str, str]]:
        if not isinstance(payload, list):
            return []

        allowed_domains = set(RESEARCH_DOMAINS)
        used_domains = set()
        normalized: List[Dict[str, str]] = []

        for item in payload:
            if not isinstance(item, dict):
                continue

            topic = str(item.get("topic", "")).strip()
            content = str(item.get("content", "")).strip()
            domain = str(item.get("domain", "")).strip()

            if not topic or not content:
                continue

            if domain not in allowed_domains or domain in used_domains:
                available = [d for d in RESEARCH_DOMAINS if d not in used_domains]
                if not available:
                    break
                domain = available[0]

            used_domains.add(domain)
            normalized.append({"domain": domain, "topic": topic, "content": content})

            if len(normalized) == 5:
                break

        return normalized[:5]


gemini_service = GeminiService()
