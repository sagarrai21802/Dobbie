from datetime import datetime, timedelta
from fastapi import APIRouter, Depends, Query
from typing import List, Optional
import httpx
from bs4 import BeautifulSoup
import random

from app.utils.dependencies import check_subscription

router = APIRouter(prefix="/topics", tags=["topics"])

# ============================================
# In-memory cache (1 hour TTL)
# ============================================

_topic_cache: dict = {}
CACHE_TTL_SECONDS = 3600


def _get_cached_topics(platform: str) -> Optional[List[dict]]:
    """Get cached topics if not expired."""
    if platform in _topic_cache:
        cached_time, topics = _topic_cache[platform]
        if (datetime.now() - cached_time).total_seconds() < CACHE_TTL_SECONDS:
            return topics
    return None


def _set_cached_topics(platform: str, topics: List[dict]):
    """Cache topics with current timestamp."""
    _topic_cache[platform] = (datetime.now(), topics)


# ============================================
# Platform-specific topic filters
# ============================================

PLATFORM_KEYWORDS = {
    "linkedin": ["professional", "career", "leadership", "business", "industry", "workplace", "job", "skills", "networking", "startup", "management", "remote work"],
    "pinterest": ["home decor", "fashion", "DIY", "recipes", "lifestyle", "beauty", "travel", "wedding", "gardening", "interior design"],
    "youtube": ["tutorial", "review", "gaming", "vlog", "tech", "music", "entertainment", "how-to", "unboxing"],
    "twitter": ["trending", "news", "memes", "politics", "sports", "pop culture", "technology", "current events"],
}


def _filter_topics_by_platform(topics: List[str], platform: str) -> List[str]:
    """Filter topics by platform relevance."""
    keywords = PLATFORM_KEYWORDS.get(platform.lower(), [])
    if not keywords:
        return topics[:10]
    
    # Score topics by keyword relevance
    scored = []
    for topic in topics:
        topic_lower = topic.lower()
        score = sum(1 for kw in keywords if kw in topic_lower)
        scored.append((score, topic))
    
    # Sort by score (descending) and return top topics
    scored.sort(key=lambda x: x[0], reverse=True)
    return [t for _, t in scored[:10]]


# ============================================
# Topic Sources
# ============================================

async def _fetch_google_trends() -> List[dict]:
    """Fetch trending topics from Google Trends RSS."""
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            response = await client.get(
                "https://trends.google.com/trends/trendingsearches/daily/rss?geo=IN"
            )
            if response.status_code != 200:
                return []
            
            soup = BeautifulSoup(response.text, "xml")
            items = soup.find_all("item")
            
            topics = []
            for item in items[:10]:
                title = item.find("title")
                if title:
                    topics.append({
                        "title": title.text.strip(),
                        "description": "Trending in India",
                        "source": "google_trends"
                    })
            return topics
    except Exception:
        return []


async def _fetch_curated_topics(platform: str) -> List[dict]:
    """Return curated fallback topics based on platform."""
    curated_by_platform = {
        "linkedin": [
            "AI in the workplace: Opportunities and challenges",
            "Remote work culture evolution",
            "Startup funding trends 2026",
            "Mental health at work",
            "Sustainable business practices",
            "Leadership in the digital age",
            "Skills that matter in 2026",
            "Career pivot strategies",
            "Building personal brand on LinkedIn",
            "Networking tips for professionals",
        ],
        "pinterest": [
            "Minimalist home decor ideas",
            "Summer fashion trends 2026",
            "DIY home organization hacks",
            "Healthy quick recipes",
            "Garden design inspiration",
            "Beauty routine essentials",
            "Wedding planning on a budget",
            "Interior paint color trends",
            "Travel packing tips",
            "Craft projects for beginners",
        ],
        "youtube": [
            "Best tech reviews 2026",
            "Gaming highlights and tips",
            "Life hack tutorials",
            "Cooking easy meals",
            "Workout routines at home",
            "Travel vlog destinations",
            "Music production basics",
            "Photography for beginners",
            "DIY electronics projects",
            "Language learning tips",
        ],
        "twitter": [
            "Tech industry news",
            "Sports updates and highlights",
            "Political discussions",
            "Pop culture trends",
            "Memes and viral content",
            "Cryptocurrency updates",
            "Climate change awareness",
            "Entertainment news",
            "Productivity tips",
            "Random thoughts",
        ],
    }
    
    topics = curated_by_platform.get(platform.lower(), curated_by_platform["linkedin"])
    # Shuffle and return with source
    random.shuffle(topics)
    return [
        {"title": t, "description": "Trending topic", "source": "curated"}
        for t in topics[:10]
    ]


async def _fetch_web_topics(platform: str) -> List[dict]:
    """Web scrape trending topics as fallback."""
    # For now, just use curated topics
    return await _fetch_curated_topics(platform)


# ============================================
# Main endpoint
# ============================================

@router.get("/trending")
async def get_trending_topics(
    platform: str = Query(..., description="Platform: linkedin, pinterest, youtube, twitter"),
    count: int = Query(7, ge=1, le=10, description="Number of topics to return"),
    current_user: dict = Depends(check_subscription)
) -> dict:
    """
    Get trending topics for a given platform.
    
    Auth required + subscription required.
    
    Returns topics from Google Trends RSS, falling back to curated list.
    Cached for 1 hour per platform.
    """
    platform_lower = platform.lower()
    
    # Check cache first
    cached = _get_cached_topics(platform_lower)
    if cached:
        return {"topics": cached[:count]}
    
    # Try Google Trends
    topics = await _fetch_google_trends()
    
    if not topics:
        # Fallback to curated topics
        topics = await _fetch_curated_topics(platform_lower)
    
    # Filter by platform relevance
    if platform_lower in PLATFORM_KEYWORDS:
        raw_titles = [t["title"] for t in topics]
        filtered_titles = _filter_topics_by_platform(raw_titles, platform_lower)
        topics = [t for t in topics if t["title"] in filtered_titles]
        # Re-sort to match filtered order
        topics = sorted(topics, key=lambda t: filtered_titles.index(t["title"]) if t["title"] in filtered_titles else 999)
    
    # Cache the results
    _set_cached_topics(platform_lower, topics)
    
    return {"topics": topics[:count]}