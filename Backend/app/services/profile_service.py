import re
from datetime import datetime, timezone
from io import BytesIO
from typing import Any, Dict, List, Optional, Tuple

import pdfplumber


class ProfileService:
    MAX_PDF_SIZE_BYTES = 5 * 1024 * 1024
    SECTION_ALIASES = {
        "Top Skills": ["top skills", "skills", "technical skills", "core skills", "key skills"],
        "Experience": ["experience", "work experience", "employment", "professional experience"],
        "Education": ["education", "academic background", "qualifications"],
        "Summary": ["summary", "about", "profile", "objective", "about me"],
        "Contact": ["contact", "contact info", "contact information"],
        "Certifications": ["certifications", "certificates", "licenses & certifications"],
        "Languages": ["languages"],
        "Honors-Awards": ["honors-awards", "honors & awards", "awards"],
        "Volunteer Experience": ["volunteer experience", "volunteering"],
        "Publications": ["publications"],
        "Projects": ["projects"],
        "Courses": ["courses"],
        "Recommendations": ["recommendations"],
        "Accomplishments": ["accomplishments"],
    }
    TECH_KEYWORDS = [
        "python",
        "java",
        "swift",
        "swiftui",
        "kotlin",
        "flutter",
        "dart",
        "react",
        "node.js",
        "express",
        "django",
        "fastapi",
        "spring boot",
        "javascript",
        "typescript",
        "html",
        "css",
        "sql",
        "mongodb",
        "postgresql",
        "redis",
        "docker",
        "kubernetes",
        "aws",
        "gcp",
        "azure",
        "git",
        "ci/cd",
        "rest api",
        "graphql",
        "machine learning",
        "tensorflow",
        "pytorch",
        "figma",
        "xcode",
        "android studio",
        "firebase",
        "supabase",
        "system design",
        "mvvm",
        "mvc",
        "core data",
        "urlsession",
        "fastlane",
    ]
    MONTH_MAP = {
        "january": 1,
        "jan": 1,
        "february": 2,
        "feb": 2,
        "march": 3,
        "mar": 3,
        "april": 4,
        "apr": 4,
        "may": 5,
        "june": 6,
        "jun": 6,
        "july": 7,
        "jul": 7,
        "august": 8,
        "aug": 8,
        "september": 9,
        "sep": 9,
        "october": 10,
        "oct": 10,
        "november": 11,
        "nov": 11,
        "december": 12,
        "dec": 12,
    }
    MONTH_PATTERN = (
        r"(?:jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|"
        r"jul(?:y)?|aug(?:ust)?|sep(?:tember)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)"
    )
    DATE_RANGE_PATTERNS = [
        re.compile(
            rf"(?P<sm>{MONTH_PATTERN})\s+(?P<sy>\d{{4}})\s*[-\u2013\u2014]\s*"
            rf"(?:(?P<epresent>present)|(?P<em>{MONTH_PATTERN})\s+(?P<ey>\d{{4}})|(?P<ey_only>\d{{4}}))",
            re.IGNORECASE,
        ),
        re.compile(
            r"(?P<smm>0?[1-9]|1[0-2])/(?P<sy>\d{4})\s*[-\u2013\u2014]\s*"
            r"(?:(?P<epresent>present)|(?P<emm>0?[1-9]|1[0-2])/(?P<ey>\d{4})|(?P<ey_only>\d{4}))",
            re.IGNORECASE,
        ),
        re.compile(
            r"(?<!\d)(?P<sy>\d{4})\s*[-\u2013\u2014]\s*(?:(?P<epresent>present)|(?P<ey>\d{4}))(?!\d)",
            re.IGNORECASE,
        ),
    ]

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
                page_text = page.extract_text(
                    x_tolerance=2,
                    y_tolerance=2,
                    layout=False,
                ) or ""
                if page_text.strip():
                    text_parts.append(page_text)
        return "\n".join(text_parts).strip()

    @staticmethod
    def _normalize_line(line: str) -> str:
        return re.sub(r"\s+", " ", line.strip().lower()).rstrip(":")

    @staticmethod
    def _is_email(text: str) -> bool:
        return bool(re.search(r"[\w.+-]+@[\w.-]+\.[a-zA-Z]{2,}", text))

    @staticmethod
    def _is_phone(text: str) -> bool:
        if not re.search(r"[\d\s\-+()]{10,}", text):
            return False
        digits = re.sub(r"\D", "", text)
        return len(digits) >= 10

    @staticmethod
    def _is_url(text: str) -> bool:
        return bool(re.search(r"(https?://|www\.)", text.lower()))

    @staticmethod
    def _section_lookup() -> Dict[str, str]:
        lookup: Dict[str, str] = {}
        for canonical, aliases in ProfileService.SECTION_ALIASES.items():
            lookup[ProfileService._normalize_line(canonical)] = canonical
            for alias in aliases:
                lookup[ProfileService._normalize_line(alias)] = canonical
        return lookup

    @staticmethod
    def _canonical_section_from_line(line: str) -> Optional[str]:
        normalized = ProfileService._normalize_line(line)
        return ProfileService._section_lookup().get(normalized)

    @staticmethod
    def _is_section_header_line(line: str) -> bool:
        return ProfileService._canonical_section_from_line(line) is not None

    @staticmethod
    def _parse_date_range(line: str) -> Optional[Tuple[int, int, int, int]]:
        now = datetime.now()

        for pattern in ProfileService.DATE_RANGE_PATTERNS:
            match = pattern.search(line)
            if not match:
                continue

            start_year = int(match.group("sy"))

            if match.groupdict().get("sm"):
                start_month = ProfileService.MONTH_MAP.get(match.group("sm").lower(), 1)
            elif match.groupdict().get("smm"):
                start_month = int(match.group("smm"))
            else:
                start_month = 1

            end_present = bool(match.groupdict().get("epresent"))
            if end_present:
                end_year = now.year
                end_month = now.month
            elif match.groupdict().get("em") and match.groupdict().get("ey"):
                end_year = int(match.group("ey"))
                end_month = ProfileService.MONTH_MAP.get(match.group("em").lower(), now.month)
            elif match.groupdict().get("emm") and match.groupdict().get("ey"):
                end_year = int(match.group("ey"))
                end_month = int(match.group("emm"))
            elif match.groupdict().get("ey_only"):
                end_year = int(match.group("ey_only"))
                end_month = 12
            elif match.groupdict().get("ey"):
                end_year = int(match.group("ey"))
                end_month = 12
            else:
                end_year = now.year
                end_month = now.month

            return start_year, start_month, end_year, end_month

        return None

    @staticmethod
    def _line_can_be_identity(line: str) -> bool:
        value = line.strip()
        return bool(
            value
            and len(value) < 60
            and not ProfileService._is_section_header_line(value)
            and not ProfileService._is_email(value)
            and not ProfileService._is_phone(value)
            and not ProfileService._is_url(value)
            and not ProfileService._parse_date_range(value)
            and not value.lower().startswith("page ")
        )

    @staticmethod
    def _split_sections(text: str) -> Dict[str, str]:
        sections: Dict[str, str] = {}
        lines = text.split("\n")

        current_section = "HEADER"
        current_lines: List[str] = []

        for line in lines:
            canonical = ProfileService._canonical_section_from_line(line)
            if canonical:
                sections[current_section] = "\n".join(current_lines).strip()
                current_section = canonical
                current_lines = []
            else:
                current_lines.append(line)

        sections[current_section] = "\n".join(current_lines).strip()
        return sections

    @staticmethod
    def _parse_header(header_text: str) -> Dict[str, str]:
        lines = [line.strip() for line in header_text.split("\n") if line.strip()]
        lines = [line for line in lines if not line.startswith("Page ")]

        name = ""
        headline = ""

        for line in lines:
            if ProfileService._line_can_be_identity(line):
                name = line
                break

        if name:
            name_index = lines.index(name)
            for line in lines[name_index + 1 :]:
                if ProfileService._line_can_be_identity(line):
                    headline = line
                    break

        location = ""
        for line in lines:
            if (
                "," in line
                and len(line) < 60
                and not ProfileService._is_email(line)
                and not ProfileService._is_url(line)
                and not ProfileService._is_section_header_line(line)
            ):
                location = line
                break

        return {
            "name": name,
            "headline": headline,
            "location": location,
        }

    @staticmethod
    def _dedupe(values: List[str]) -> List[str]:
        seen = set()
        ordered: List[str] = []
        for value in values:
            normalized = value.strip().lower()
            if not normalized or normalized in seen:
                continue
            seen.add(normalized)
            ordered.append(value.strip())
        return ordered

    @staticmethod
    def _extract_keywords_from_text(text: str) -> List[str]:
        lowered = text.lower()
        matches: List[str] = []
        for keyword in ProfileService.TECH_KEYWORDS:
            if keyword in lowered:
                matches.append(keyword)
        return ProfileService._dedupe(matches)

    @staticmethod
    def _parse_skills(skills_text: str, full_text: str) -> List[str]:
        lines = [line.strip() for line in skills_text.split("\n") if line.strip()]
        skills = []

        for line in lines:
            if line.startswith("Page ") or re.match(r"^\d+$", line):
                continue
            if "," in line:
                skills.extend([item.strip() for item in line.split(",") if item.strip()])
            elif len(line) > 1 and not ProfileService._is_section_header_line(line):
                skills.append(line)

        if not skills:
            all_lines = [line.strip() for line in full_text.split("\n") if line.strip()]
            for index, line in enumerate(all_lines):
                canonical = ProfileService._canonical_section_from_line(line)
                if canonical != "Top Skills":
                    continue
                for next_line in all_lines[index + 1 : index + 16]:
                    if ProfileService._is_section_header_line(next_line):
                        break
                    if not next_line or next_line.startswith("Page "):
                        continue
                    if "," in next_line:
                        skills.extend([item.strip() for item in next_line.split(",") if item.strip()])
                    else:
                        skills.append(next_line)
                break

        skills.extend(ProfileService._extract_keywords_from_text(full_text))
        return ProfileService._dedupe(skills)[:20]

    @staticmethod
    def _parse_experience(exp_text: str) -> Dict[str, Any]:
        lines = [line.strip() for line in exp_text.split("\n") if line.strip()]
        lines = [line for line in lines if not line.startswith("Page ")]

        current_role = ""
        current_company = ""
        total_months = 0

        first_role_found = False

        for index, line in enumerate(lines):
            date_range = ProfileService._parse_date_range(line)
            if not date_range:
                continue

            start_year, start_month, end_year, end_month = date_range

            months = (end_year - start_year) * 12 + (end_month - start_month)
            total_months += max(0, months)

            if not first_role_found and index > 0:
                for candidate_index in [index - 1, index - 2, index + 1]:
                    if candidate_index < 0 or candidate_index >= len(lines):
                        continue
                    candidate = lines[candidate_index]
                    if (
                        candidate
                        and not ProfileService._parse_date_range(candidate)
                        and not ProfileService._is_section_header_line(candidate)
                    ):
                        current_role = candidate
                        break

                if index > 1 and lines[index - 2] != current_role:
                    current_company = lines[index - 2]
                first_role_found = True

        years = round(total_months / 12, 1)
        years_int = int(years) if years > 0 else None

        return {
            "current_role": current_role,
            "current_company": current_company,
            "years_experience": years_int,
        }

    @staticmethod
    def _extract_generic_resume_profile(text: str) -> Dict[str, Any]:
        lines = [line.strip() for line in text.split("\n") if line.strip()]

        email_match = re.search(r"[\w.+-]+@[\w.-]+\.[a-zA-Z]{2,}", text)
        email = email_match.group(0) if email_match else ""

        phone = ""
        for line in lines:
            if ProfileService._is_phone(line):
                phone = line
                break

        name = ""
        headline = ""
        for line in lines:
            if ProfileService._line_can_be_identity(line):
                name = line
                break

        if name:
            start = lines.index(name) + 1
            for line in lines[start:]:
                if ProfileService._line_can_be_identity(line):
                    headline = line
                    break

        years_months = 0
        role = ""
        for index, line in enumerate(lines):
            date_range = ProfileService._parse_date_range(line)
            if not date_range:
                continue

            start_year, start_month, end_year, end_month = date_range
            years_months += max(0, (end_year - start_year) * 12 + (end_month - start_month))

            for candidate_index in [index - 1, index + 1]:
                if candidate_index < 0 or candidate_index >= len(lines):
                    continue
                candidate = lines[candidate_index]
                if ProfileService._line_can_be_identity(candidate):
                    role = candidate
                    break
            if role:
                break

        comma_skills: List[str] = []
        for line in lines:
            if line.count(",") < 2:
                continue
            parts = [part.strip() for part in line.split(",") if part.strip()]
            if len(parts) >= 3:
                comma_skills.extend(parts)

        keyword_skills = ProfileService._extract_keywords_from_text(text)
        skills = ProfileService._dedupe(comma_skills + keyword_skills)[:20]

        years_int = int(round(years_months / 12)) if years_months > 0 else None
        location = ""
        for line in lines:
            if "," in line and len(line) < 60 and not ProfileService._is_email(line):
                location = line
                break

        industry = ProfileService._infer_industry(headline, role, skills)
        tone = ProfileService._infer_tone(text)

        _ = email
        _ = phone

        return {
            "name": name,
            "headline": headline,
            "location": location,
            "current_role": role,
            "industry": industry,
            "skills": skills,
            "years_experience": years_int,
            "preferred_tone": tone,
        }

    @staticmethod
    def _infer_industry(headline: str, role: str, skills: List[str]) -> str:
        combined = f"{headline} {role} {' '.join(skills)}".lower()

        rules = [
            (["ios", "swift", "android", "flutter", "mobile"], "Mobile Development"),
            (
                ["machine learning", "ai", "data science", "nlp", "deep learning"],
                "AI / Machine Learning",
            ),
            (
                ["backend", "java", "spring", "node", "python", "fastapi", "django"],
                "Backend Engineering",
            ),
            (["frontend", "react", "vue", "angular", "css", "html"], "Frontend Development"),
            (["devops", "kubernetes", "docker", "ci/cd", "aws", "cloud"], "DevOps / Cloud"),
            (["product manager", "product owner", "roadmap"], "Product Management"),
            (["design", "figma", "ux", "ui designer"], "Design"),
            (["finance", "banking", "investment", "trading"], "Finance"),
            (["marketing", "seo", "growth", "content"], "Marketing"),
            (["sales", "business development", "crm"], "Sales"),
        ]

        for keywords, industry in rules:
            if any(keyword in combined for keyword in keywords):
                return industry

        return "Technology"

    @staticmethod
    def _infer_tone(summary_text: str) -> str:
        text = summary_text.lower()

        if any(word in text for word in ["i believe", "passionate", "journey", "dream", "inspire"]):
            return "inspirational"
        if any(word in text for word in ["engineer", "architect", "system", "optimize", "performance"]):
            return "technical"
        if any(word in text for word in ["collaborate", "team", "partner", "client", "stakeholder"]):
            return "professional"
        return "conversational"

    @staticmethod
    async def extract_profile_from_pdf(file_bytes: bytes) -> Dict[str, Any]:
        extracted_text = ProfileService.extract_text_from_pdf(file_bytes)
        if not extracted_text:
            raise ValueError("Could not extract readable text from PDF")

        sections = ProfileService._split_sections(extracted_text)

        non_header_sections = [
            key for key, value in sections.items() if key != "HEADER" and value.strip()
        ]
        if len(non_header_sections) < 3:
            generic = ProfileService._extract_generic_resume_profile(extracted_text)
            return ProfileService._normalize_profile_payload(generic)

        header = ProfileService._parse_header(sections.get("HEADER", ""))
        skills = ProfileService._parse_skills(sections.get("Top Skills", ""), extracted_text)
        experience = ProfileService._parse_experience(sections.get("Experience", ""))
        industry = ProfileService._infer_industry(
            header["headline"],
            experience["current_role"],
            skills,
        )
        tone = ProfileService._infer_tone(sections.get("Summary", ""))

        extracted = {
            "name": header["name"],
            "headline": header["headline"],
            "location": header["location"],
            "current_role": experience["current_role"],
            "industry": industry,
            "skills": skills,
            "years_experience": experience["years_experience"],
            "preferred_tone": tone,
        }

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
