import asyncio
import json
from pathlib import Path

import asyncpg

from .config import settings

_pool: asyncpg.Pool | None = None
_init_lock = asyncio.Lock()


async def _init_connection(conn: asyncpg.Connection) -> None:
    """Set up JSONB codec so Python dicts can be passed to JSONB columns directly."""
    await conn.set_type_codec(
        "jsonb",
        encoder=json.dumps,
        decoder=json.loads,
        schema="pg_catalog",
    )


async def get_pool() -> asyncpg.Pool:
    global _pool
    if _pool is not None:
        return _pool
    async with _init_lock:
        if _pool is None:
            _pool = await asyncpg.create_pool(
                settings.database_url,
                min_size=2,
                max_size=10,
                init=_init_connection,
            )
            schema_sql = (Path(__file__).parent / "schema.sql").read_text()
            async with _pool.acquire() as conn:
                await conn.execute(schema_sql)
    return _pool


async def close_pool() -> None:
    global _pool
    if _pool is not None:
        await _pool.close()
        _pool = None
