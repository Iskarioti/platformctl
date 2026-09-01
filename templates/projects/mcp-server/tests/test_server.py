from app.server import echo


def test_echo() -> None:
    assert echo("hello") == "hello"
