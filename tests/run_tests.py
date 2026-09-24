"""Execute the addon regression suite using Lua 5.1, not Lua 5.4."""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / ".test-deps"))
try:
    from lupa.lua51 import LuaRuntime
except ImportError:
    raise SystemExit("Install test dependencies: python -m pip install -r requirements-dev.txt")

lua = LuaRuntime(unpack_returned_tuples=True)
lua.globals().ADDON_SOURCE = (ROOT / "PartyTargetWatch/PartyTargetWatch.lua").read_text(encoding="utf-8")
lua.execute((ROOT / "tests/test_addon.lua").read_text(encoding="utf-8"))
