from app.prompts import QA_PROMPT_VERSION, render_qa_prompt


def test_render_qa_prompt_includes_context_and_question() -> None:
    prompt = render_qa_prompt("platformctl is a workstation-as-code repo.", "What is platformctl?")
    assert "platformctl is a workstation-as-code repo." in prompt
    assert "What is platformctl?" in prompt


def test_prompt_version_is_set() -> None:
    assert QA_PROMPT_VERSION
