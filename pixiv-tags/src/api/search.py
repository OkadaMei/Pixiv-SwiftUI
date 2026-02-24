import logging
from typing import Dict, List, Optional

from .client import NetworkClient

logger = logging.getLogger(__name__)


class SearchAPI:
    """Pixiv 搜索 API"""

    def __init__(self, client: NetworkClient):
        self.client = client

    def get_recommended_illusts(self, offset: int = 0, limit: int = 30) -> List[Dict]:
        """
        获取推荐插画流

        Args:
            offset: 偏移量
            limit: 返回数量限制

        Returns:
            插画列表，每个插画包含 tags 信息
        """
        params = {
            "filter": "for_ios",
            "include_ranking_label": "true",
            "offset": str(offset),
            "limit": str(limit),
        }

        try:
            result = self.client.get("/v1/illust/recommended", params=params)
            illusts = result.get("illusts", [])
            logger.debug(f"Got {len(illusts)} recommended illusts (offset={offset})")
            return illusts

        except Exception as e:
            logger.error(f"Failed to get recommended illusts: {e}")
            return []

    def search_illust_by_tag(
        self,
        word: str,
        offset: int = 0,
        limit: int = 30,
        start_date: Optional[str] = None,
        end_date: Optional[str] = None,
    ) -> Dict:
        """
        按标签搜索插画

        Args:
            word: 搜索关键词（标签名）
            offset: 偏移量
            limit: 返回数量限制
            start_date: 开始日期 (YYYY-MM-DD)
            end_date: 结束日期 (YYYY-MM-DD)

        Returns:
            API 响应字典，包含 illusts 和 next_url
        """
        params = {
            "word": word,
            "search_target": "partial_match_for_tags",
            "sort": "date_desc",
            "offset": str(offset),
        }

        if start_date:
            params["start_date"] = start_date
        if end_date:
            params["end_date"] = end_date

        try:
            result = self.client.get("/v1/search/illust", params=params)
            return result

        except Exception as e:
            logger.error(f"Failed to search illusts for tag '{word}': {e}")
            return {}
