from mcp.server.fastmcp import FastMCP

mcp = FastMCP("__PROJECT_NAME__")


@mcp.tool()
def echo(text: str) -> str:
    """Echo the input text back - a minimal example tool to replace with real ones."""
    return text


if __name__ == "__main__":
    mcp.run()
