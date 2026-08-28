from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_prefix="", case_sensitive=False)

    app_env: str = "development"
    database_url: str = "postgresql+psycopg://developer:development-only@postgres:5432/application"
    redis_url: str = "redis://redis:6379/0"


settings = Settings()
