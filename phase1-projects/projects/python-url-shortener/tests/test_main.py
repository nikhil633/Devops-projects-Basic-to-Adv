import pytest
from httpx import AsyncClient, ASGITransport
from unittest.mock import AsyncMock, patch
from app.main import app

@pytest.mark.asyncio
async def test_health():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        resp = await client.get("/health")
    assert resp.status_code == 200
    assert resp.json()["status"] == "ok"

@pytest.mark.asyncio
async def test_shorten_and_redirect():
    mock_redis = AsyncMock()
    mock_redis.get.return_value = "https://www.example.com"
    with patch("app.main.get_redis", return_value=mock_redis):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            resp = await client.post("/shorten", json={"url": "https://www.example.com"})
            assert resp.status_code == 200
            data = resp.json()
            assert "short_code" in data

@pytest.mark.asyncio
async def test_redirect_not_found():
    mock_redis = AsyncMock()
    mock_redis.get.return_value = None
    with patch("app.main.get_redis", return_value=mock_redis):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            resp = await client.get("/notexist", follow_redirects=False)
        assert resp.status_code == 404
