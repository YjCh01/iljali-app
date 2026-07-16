"""소셜 OAuth — 카카오·네이버·구글·애플 (키 미설정 시 mock)."""

from __future__ import annotations

import logging
import secrets
from dataclasses import dataclass
from typing import Any
from urllib.parse import urlencode

import httpx

from app.config import settings

logger = logging.getLogger(__name__)

SOCIAL_PROVIDERS = frozenset({"kakao", "naver", "google"})


@dataclass(frozen=True)
class SocialProfile:
    provider: str
    provider_user_id: str
    email: str
    display_name: str


def social_mock_enabled() -> bool:
    if settings.social_auth_mock:
        return True
    return not any(
        [
            _kakao_client_id(),
            settings.naver_oauth_client_id.strip(),
            settings.google_oauth_client_id.strip(),
        ]
    )


def provider_configured(provider: str) -> bool:
    if social_mock_enabled():
        return True
    if provider == "kakao":
        return bool(_kakao_client_id())
    if provider == "naver":
        return bool(settings.naver_oauth_client_id.strip())
    if provider == "google":
        return bool(settings.google_oauth_client_id.strip())
    return False


def _kakao_client_id() -> str:
    return (
        settings.kakao_oauth_client_id.strip()
        or settings.kakao_rest_api_key.strip()
    )


def _validate_kakao_client_id(client_id: str) -> None:
    """KOE101 — 키 오타·잘림·공백 시 카카오가 거부."""
    if len(client_id) < 20:
        raise ValueError("kakao_client_id_invalid_length")


def api_callback_url(provider: str) -> str:
    base = settings.api_public_base_url.rstrip("/")
    return f"{base}/v1/auth/social/{provider}/callback"


def build_authorize_url(*, provider: str, state: str) -> str:
    redirect_uri = api_callback_url(provider)
    if social_mock_enabled():
        params = urlencode({"code": f"mock_{provider}", "state": state})
        return f"{api_callback_url(provider)}?{params}"

    if provider == "kakao":
        client_id = _kakao_client_id()
        if not client_id:
            raise ValueError("kakao_not_configured")
        _validate_kakao_client_id(client_id)
        params = urlencode(
            {
                "client_id": client_id,
                "redirect_uri": redirect_uri,
                "response_type": "code",
                "state": state,
                "scope": "profile_nickname,account_email",
            }
        )
        return f"https://kauth.kakao.com/oauth/authorize?{params}"

    if provider == "naver":
        client_id = settings.naver_oauth_client_id.strip()
        if not client_id:
            raise ValueError("naver_not_configured")
        params = urlencode(
            {
                "response_type": "code",
                "client_id": client_id,
                "redirect_uri": redirect_uri,
                "state": state,
            }
        )
        return f"https://nid.naver.com/oauth2.0/authorize?{params}"

    if provider == "google":
        client_id = settings.google_oauth_client_id.strip()
        if not client_id:
            raise ValueError("google_not_configured")
        params = urlencode(
            {
                "client_id": client_id,
                "redirect_uri": redirect_uri,
                "response_type": "code",
                "scope": "openid email profile",
                "state": state,
                "access_type": "online",
                "prompt": "select_account",
            }
        )
        return f"https://accounts.google.com/o/oauth2/v2/auth?{params}"

    raise ValueError("invalid_provider")


def exchange_code_for_profile(
    *, provider: str, code: str, state: str = ""
) -> SocialProfile:
    if code.startswith("mock_") or social_mock_enabled() and code.startswith("mock"):
        mock_provider = code.removeprefix("mock_")
        suffix = secrets.token_hex(4)
        return SocialProfile(
            provider=mock_provider or provider,
            provider_user_id=f"mock_{mock_provider or provider}_{suffix}",
            email=f"social.{suffix}@iljari.mock",
            display_name=f"{(mock_provider or provider).title()} 사용자",
        )

    redirect_uri = api_callback_url(provider)
    with httpx.Client(timeout=20.0) as client:
        if provider == "kakao":
            return _kakao_profile(client, code=code, redirect_uri=redirect_uri)
        if provider == "naver":
            return _naver_profile(
                client, code=code, redirect_uri=redirect_uri, state=state
            )
        if provider == "google":
            return _google_profile(client, code=code, redirect_uri=redirect_uri)
    raise ValueError("invalid_provider")


def kakao_oauth_secret_configured() -> bool:
    return bool(settings.kakao_oauth_client_secret.strip())


def _kakao_token_error(res: httpx.Response) -> ValueError:
    try:
        body: dict[str, Any] = res.json()
    except Exception:
        body = {}
    err = str(body.get("error") or "")
    desc = str(body.get("error_description") or body.get("error_code") or "")
    blob = f"{err} {desc}".lower()
    logger.warning("kakao token error status=%s body=%s", res.status_code, body)
    if "invalid_client" in blob or "koe101" in blob or "koe010" in blob:
        return ValueError("kakao_invalid_client")
    if "redirect" in blob or "koe303" in blob or "koe006" in blob:
        return ValueError("kakao_redirect_mismatch")
    if err == "invalid_grant":
        return ValueError("kakao_code_expired")
    return ValueError("oauth_failed")


def _kakao_profile(
    client: httpx.Client, *, code: str, redirect_uri: str
) -> SocialProfile:
    client_id = _kakao_client_id()
    secret = settings.kakao_oauth_client_secret.strip()
    if not secret:
        logger.error("kakao oauth: client_secret missing in server .env")
        raise ValueError("kakao_secret_missing")

    data: dict[str, str] = {
        "grant_type": "authorization_code",
        "client_id": client_id,
        "client_secret": secret,
        "redirect_uri": redirect_uri,
        "code": code,
    }
    token_res = client.post("https://kauth.kakao.com/oauth/token", data=data)
    if token_res.status_code >= 400:
        raise _kakao_token_error(token_res)
    token_body = token_res.json()
    access_token = token_body.get("access_token")
    if not access_token:
        raise ValueError("kakao_token_failed")

    me_res = client.get(
        "https://kapi.kakao.com/v2/user/me",
        headers={"Authorization": f"Bearer {access_token}"},
    )
    if me_res.status_code >= 400:
        logger.warning("kakao /v2/user/me failed status=%s body=%s", me_res.status_code, me_res.text[:500])
        raise ValueError("kakao_profile_failed")
    body: dict[str, Any] = me_res.json()
    kakao_id = str(body.get("id") or "")
    account = body.get("kakao_account") if isinstance(body.get("kakao_account"), dict) else {}
    profile = account.get("profile") if isinstance(account.get("profile"), dict) else {}
    email = str(account.get("email") or "").strip().lower()
    name = str(profile.get("nickname") or account.get("name") or "카카오 사용자").strip()
    if not email:
        email = f"kakao_{kakao_id}@social.iljari.app"
    return SocialProfile(
        provider="kakao",
        provider_user_id=kakao_id,
        email=email,
        display_name=name,
    )


def _naver_profile(
    client: httpx.Client, *, code: str, redirect_uri: str, state: str
) -> SocialProfile:
    if not state.strip():
        raise ValueError("naver_state_missing")
    client_id = settings.naver_oauth_client_id.strip()
    secret = settings.naver_oauth_client_secret.strip()
    if not client_id or not secret:
        raise ValueError("naver_not_configured")
    params = {
        "grant_type": "authorization_code",
        "client_id": client_id,
        "client_secret": secret,
        "code": code,
        "state": state,
    }
    token_res = client.get("https://nid.naver.com/oauth2.0/token", params=params)
    if token_res.status_code >= 400:
        logger.warning(
            "naver token error status=%s body=%s",
            token_res.status_code,
            token_res.text[:500],
        )
        raise ValueError("naver_token_failed")
    token_body = token_res.json()
    access_token = token_body.get("access_token")
    if not access_token:
        raise ValueError("naver_token_failed")

    me_res = client.get(
        "https://openapi.naver.com/v1/nid/me",
        headers={"Authorization": f"Bearer {access_token}"},
    )
    me_res.raise_for_status()
    response = me_res.json().get("response") or {}
    naver_id = str(response.get("id") or "")
    email = str(response.get("email") or "").strip().lower()
    name = str(response.get("name") or response.get("nickname") or "네이버 사용자").strip()
    if not email:
        email = f"naver_{naver_id}@social.iljari.app"
    return SocialProfile(
        provider="naver",
        provider_user_id=naver_id,
        email=email,
        display_name=name,
    )


def _google_profile(
    client: httpx.Client, *, code: str, redirect_uri: str
) -> SocialProfile:
    client_id = settings.google_oauth_client_id.strip()
    secret = settings.google_oauth_client_secret.strip()
    if not client_id or not secret:
        raise ValueError("google_not_configured")
    token_res = client.post(
        "https://oauth2.googleapis.com/token",
        data={
            "grant_type": "authorization_code",
            "client_id": client_id,
            "client_secret": secret,
            "code": code,
            "redirect_uri": redirect_uri,
        },
    )
    if token_res.status_code >= 400:
        logger.warning(
            "google token error status=%s body=%s",
            token_res.status_code,
            token_res.text[:500],
        )
        raise ValueError("google_token_failed")
    token_body = token_res.json()
    access_token = token_body.get("access_token")
    if not access_token:
        raise ValueError("google_token_failed")

    me_res = client.get(
        "https://www.googleapis.com/oauth2/v3/userinfo",
        headers={"Authorization": f"Bearer {access_token}"},
    )
    me_res.raise_for_status()
    body = me_res.json()
    google_id = str(body.get("sub") or "")
    email = str(body.get("email") or "").strip().lower()
    name = str(body.get("name") or "Google 사용자").strip()
    if not email:
        email = f"google_{google_id}@social.iljari.app"
    return SocialProfile(
        provider="google",
        provider_user_id=google_id,
        email=email,
        display_name=name,
    )


def build_app_redirect_url(
    *,
    app_redirect: str,
    status: str,
    access_token: str = "",
    social_token: str = "",
    email: str = "",
    display_name: str = "",
    provider: str = "",
    error: str = "",
    member_type: str = "",
) -> str:
    params: dict[str, str] = {"status": status}
    if access_token:
        params["access_token"] = access_token
    if social_token:
        params["social_token"] = social_token
    if email:
        params["email"] = email
    if display_name:
        params["name"] = display_name
    if provider:
        params["provider"] = provider
    if error:
        params["error"] = error
    if member_type:
        params["member_type"] = member_type
    base = app_redirect.strip() or settings.social_app_success_url
    joiner = "&" if "?" in base else "?"
    return f"{base}{joiner}{urlencode(params)}"
