from app.prompts import SYSTEM_PROMPT, SYSTEM_PROMPT_VERSION


def test_system_prompt_is_set() -> None:
    assert SYSTEM_PROMPT
    assert SYSTEM_PROMPT_VERSION
