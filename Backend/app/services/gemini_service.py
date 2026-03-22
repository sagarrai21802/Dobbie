from google import genai
from google.genai import types
from app.config import settings
from typing import Optional


class GeminiService:
    def __init__(self):
        self.client = genai.Client(
            api_key=settings.GEMINI_API_KEY,
        )
        self.model = "gemini-3-flash-preview"

    def generate_linkedin_post(self, topic: str) -> str:
        prompt = self._build_prompt(topic)

        response = self.client.models.generate_content(
            model=self.model,
            contents=prompt,
            config=types.GenerateContentConfig(
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

    def _build_prompt(self, topic: str) -> str:
        return f"""You are an expert LinkedIn content creator. Create a viral, attention-grabbing LinkedIn post about: "{topic}"

Requirements:
1. Start with a HOOK - something that stops people from scrolling (question, bold statement, or surprising fact)
2. Make it personal and relatable - use "I" or "we" to share experience
3. Add value - teach something, share insights, or provide actionable tips
4. Use minimal emojis (2-3 max) - they should enhance, not distract
5. Add 3-5 relevant hashtags at the end
6. Keep it between 150-300 words
7. Make it sound HUMAN - like you're talking to a friend, not a robot
8. Include a call-to-action or question at the end to drive engagement
9. Format with short paragraphs (2-3 sentences max) for readability

Write the post now:"""


gemini_service = GeminiService()
