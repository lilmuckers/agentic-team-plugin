from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    database_url: str = "postgresql://mcp:mcp@localhost:5432/mcp_ledger"
    host: str = "0.0.0.0"
    port: int = 8000

    model_config = {"env_file": ".env", "env_file_encoding": "utf-8"}


settings = Settings()
