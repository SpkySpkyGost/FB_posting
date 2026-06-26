import os
from dotenv import load_dotenv
import requests
from abc import ABC, abstractmethod
from django.utils.dateparse import parse_datetime

load_dotenv()

TIMEOUT_VAL_BUFFER=10
TIMEOUT_VAL_META=10

class MarketingServiceException(Exception):
    """Custom exception for external marketing API errors."""
    pass


class BaseMarketingService(ABC):
    """Abstract interface for marketing services."""

    @abstractmethod
    def publish_post(self, message: str) -> tuple[str, dict]:
        """
        Publishes a post to the platform.
        Returns a tuple: (external_id, raw_response)
        """
        pass

    @abstractmethod
    def fetch_metrics(self, post_id: str) -> tuple[dict, dict]:
        """
        Fetches metrics for a specific post.
        Returns a tuple: (normalized_metrics_dict, raw_response)
        """
        pass


class FacebookMarketingService(BaseMarketingService):
    """Service for direct interaction with the Facebook Graph API."""

    def __init__(self):
        self.page_id = os.getenv('FB_PAGE_ID')
        self.access_token = os.getenv('FB_PAGE_ACCESS_TOKEN')
        self.base_url = f"https://graph.facebook.com/{os.getenv('FB_GRAPH_VERSION')}"

    def publish_post(self, message: str) -> tuple[str, dict]:
        url = f"{self.base_url}/{self.page_id}/feed"
        try:
            response = requests.post(url, data={
                'message': message,
                'access_token': self.access_token
            }, timeout=TIMEOUT_VAL_META)
            data = response.json()
        except (requests.RequestException, ValueError) as e:
            raise MarketingServiceException(f"Network failure or data format issue with Facebook API: {e}")

        if 'id' not in data:
            raise MarketingServiceException(f"Facebook API Error: {data.get('error', data)}")

        return data['id'], data

    def fetch_metrics(self, post_id: str) -> tuple[dict, dict]:
        url = f"{self.base_url}/{post_id}"
        params = {
            'fields': 'reactions.summary(total_count).limit(0),comments.summary(total_count).limit(0),shares',
            'access_token': self.access_token,
        }
        try:
            response = requests.get(url, params=params, timeout=TIMEOUT_VAL_META)
            data = response.json()
        except (requests.RequestException, ValueError) as e:
            raise MarketingServiceException(f"Failed to fetch data from Facebook: {e}")

        if 'error' in data:
            raise MarketingServiceException(f"Facebook API Error during metrics fetch: {data['error']}")

        # Normalize data
        reactions = data.get('reactions', {}).get('summary', {}).get('total_count', 0)
        comments = data.get('comments', {}).get('summary', {}).get('total_count', 0)
        shares = data.get('shares', {}).get('count', 0)

        normalized = {
            'reactions': reactions,
            'comments': comments,
            'shares': shares,
            'engagement_total': reactions + comments + shares,
        }
        return normalized, data


class BufferMarketingService(BaseMarketingService):
    """Orchestration service via the Buffer GraphQL API."""

    def __init__(self):
        self.profile_id = os.getenv('BUFFER_PROFILE_ID')
        self.access_token = os.getenv('BUFFER_ACCESS_TOKEN')
        self.url = "https://api.buffer.com/1/graphql"
        self.headers = {
            'Authorization': f"Bearer {self.access_token}",
            'Content-Type': 'application/json'
        }

    def publish_post(self, message: str) -> tuple[str, dict]:
        mutation = """
        mutation($text: String!, $channelId: ChannelId!) {
          createPost(input: {
            text: $text, 
            channelId: $channelId,
            schedulingType: automatic,
            mode: shareNow,
            metadata: { facebook: { type: post } }
          }) {
            ... on PostActionSuccess { post { id } }
            ... on MutationError { message }
          }
        }
        """
        try:
            response = requests.post(self.url, headers=self.headers, json={
                'query': mutation,
                'variables': {
                    'text': message,
                    'channelId': self.profile_id
                }
            }, timeout=TIMEOUT_VAL_BUFFER)
            data = response.json()
        except (requests.RequestException, ValueError) as e:
            raise MarketingServiceException(f"Network failure or data format issue with Buffer API: {e}")

        # The Bridge to Facebook has been entirely removed! Flows are isolated.
        ext_id = data.get('data', {}).get('createPost', {}).get('post', {}).get('id')
        if not ext_id:
            error_details = data.get('data', {}).get('createPost', {}).get('message') or data
            raise MarketingServiceException(f"Buffer API Error: {error_details}")

        return ext_id, data

    def fetch_metrics(self, post_id: str) -> tuple[dict, dict]:
        query = """
        query($id: PostId!) { 
            post(input: { id: $id }) { 
                id 
                metrics { type value }
                metricsUpdatedAt
            } 
        }
        """
        try:
            response = requests.post(self.url, headers=self.headers, json={
                'query': query,
                'variables': {'id': post_id}
            }, timeout=TIMEOUT_VAL_BUFFER)
            data = response.json()
        except (requests.RequestException, ValueError) as e:
            raise MarketingServiceException(f"Failed to fetch data from Buffer: {e}")

        if 'errors' in data or not data.get('data', {}).get('post'):
            raise MarketingServiceException(
                f"Buffer API Error during metrics fetch: {data.get('errors', 'Post not found')}")

        # Normalize data
        metrics_list = data.get('data', {}).get('post', {}).get('metrics', [])
        metrics_map = {m.get('type'): m.get('value', 0) for m in metrics_list} if metrics_list else {}

        reactions = int(metrics_map.get('reactions', 0))
        comments = int(metrics_map.get('comments', 0))
        shares = int(metrics_map.get('shares', 0))

        remote_updated_at_str = data.get('data', {}).get('post', {}).get('metricsUpdatedAt')
        remote_updated_at = parse_datetime(remote_updated_at_str) if remote_updated_at_str else None

        normalized = {
            'reactions': reactions,
            'comments': comments,
            'shares': shares,
            'engagement_total': reactions + comments + shares,
            'metricsUpdatedAt': remote_updated_at,

        }

        return normalized, data


def get_marketing_service(mode: str) -> BaseMarketingService:
    """Factory method to get the required service based on the string mode."""
    if mode == 'Direct API':
        return FacebookMarketingService()
    elif mode == 'Orchestrated (Buffer)':
        return BufferMarketingService()
    else:
        raise ValueError(f"Unknown execution mode: {mode}")