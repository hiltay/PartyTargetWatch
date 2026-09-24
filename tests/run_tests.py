"""Run isolated WoW mocks in Lua 5.1; never touches the game or display settings."""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / ".test-deps"))
try:
    from lupa.lua51 import LuaRuntime, LuaError
except ImportError:
    raise SystemExit("Install test dependencies: python -m pip install -r requirements-dev.txt")

ADDON = ROOT / "PartyTargetWatch"
modules = []
for raw in (ADDON / "PartyTargetWatch.toc").read_text(encoding="utf-8-sig").splitlines():
    entry = raw.strip()
    if entry and not entry.startswith("#") and entry.lower().endswith(".lua"):
        path = (ADDON / entry.replace("\\", "/")).resolve()
        if not path.is_relative_to(ADDON.resolve()):
            raise SystemExit(f"TOC module escapes addon folder: {entry}")
        modules.append(path)
if not modules:
    raise SystemExit("TOC does not contain Lua modules")

failures = []
for test_path in (ROOT / "tests/test_addon.lua", ROOT / "tests/test_communication.lua"):
    if not test_path.exists():
        raise SystemExit(f"Missing required Lua suite: {test_path.name}")
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.globals().print = lambda *values: print(*values, flush=True)
    sources = lua.table()
    for index, path in enumerate(modules, 1):
        sources[index] = lua.table(name=path.name, source=path.read_text(encoding="utf-8-sig"))
    lua.globals().ADDON_SOURCES = sources
    lua.globals().ADDON_SOURCE = (ADDON / "PartyTargetWatch.lua").read_text(encoding="utf-8-sig")
    lua.globals().COMMUNICATION_SOURCE = (ADDON / "Communication.lua").read_text(encoding="utf-8-sig")
    print(f"Running {test_path.name} ({lua.eval('_VERSION')})", flush=True)
    try:
        lua.execute(test_path.read_text(encoding="utf-8-sig"))
    except LuaError as exc:
        failures.append(test_path.name)
        print(f"FAILED {test_path.name}: {exc}", file=sys.stderr, flush=True)

if failures:
    raise SystemExit("Failed suites: " + ", ".join(failures))

print("Mock suites passed. WoW secret restrictions, taint and rendering are not simulated.", flush=True)
