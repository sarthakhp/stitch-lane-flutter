"""ANSI-colored logging and interactive prompts."""

from __future__ import annotations

RED = "\033[0;31m"
GREEN = "\033[0;32m"
YELLOW = "\033[1;33m"
CYAN = "\033[0;36m"
BOLD = "\033[1m"
NC = "\033[0m"


def info(msg: str) -> None:
    print(f"{CYAN}[info]{NC}  {msg}")


def ok(msg: str) -> None:
    print(f"{GREEN}[ok]{NC}    {msg}")


def warn(msg: str) -> None:
    print(f"{YELLOW}[warn]{NC}  {msg}")


def fail(msg: str) -> None:
    print(f"{RED}[fail]{NC}  {msg}")


def step(msg: str) -> None:
    print(f"\n{BOLD}{msg}{NC}")


def pick_from_list(items: list[str], prompt: str) -> str | None:
    for i, item in enumerate(items, 1):
        print(f"   [{i}] {item}")
    print()
    try:
        choice = input(f"   {prompt} [1-{len(items)}]: ").strip()
        idx = int(choice) - 1
        if 0 <= idx < len(items):
            return items[idx]
    except (ValueError, EOFError, KeyboardInterrupt):
        pass
    fail("Invalid choice.")
    return None
