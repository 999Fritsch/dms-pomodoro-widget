#!/usr/bin/env bash
# Pomodoro Widget installer for DankMaterialShell
# Usage: ./install.sh
# Run from the repo root directory.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_SRC="$SCRIPT_DIR/PomodoroWidget"
DMS_DIR="$HOME/.config/DankMaterialShell"
PLUGINS_DIR="$DMS_DIR/plugins"
SETTINGS_FILE="$DMS_DIR/settings.json"
PLUGIN_SETTINGS="$DMS_DIR/plugin_settings.json"
TARGET_DIR="$PLUGINS_DIR/PomodoroWidget"

echo "=== Pomodoro Widget for DankMaterialShell ==="
echo ""

# Verify DMS config exists
if [[ ! -d "$DMS_DIR" ]]; then
    echo "ERROR: DankMaterialShell config not found at $DMS_DIR"
    echo "       Is DMS installed and configured?"
    exit 1
fi

if [[ ! -f "$SETTINGS_FILE" ]]; then
    echo "ERROR: settings.json not found at $SETTINGS_FILE"
    exit 1
fi

if [[ ! -f "$PLUGIN_SETTINGS" ]]; then
    echo "ERROR: plugin_settings.json not found at $PLUGIN_SETTINGS"
    exit 1
fi

# 1. Copy plugin files
echo "→ Installing plugin files to $TARGET_DIR ..."
mkdir -p "$TARGET_DIR"
cp -r "$PLUGIN_SRC/." "$TARGET_DIR/"
echo "  Done."

# 2. Add widget to settings.json (insert at index 0 of centerWidgets)
echo "→ Patching settings.json ..."
if python3 -c "import json; d=json.load(open('$SETTINGS_FILE')); exit(0 if 'pomodoroWidget' in str(d) else 1)" 2>/dev/null; then
    echo "  pomodoroWidget already present — skipping."
else
    python3 - "$SETTINGS_FILE" <<'PYEOF'
import json, sys

path = sys.argv[1]
with open(path) as f:
    data = json.load(f)

def patch(obj):
    if isinstance(obj, dict):
        if "centerWidgets" in obj:
            cw = obj["centerWidgets"]
            ids = [w if isinstance(w, str) else w.get("id", "") for w in cw]
            if "pomodoroWidget" not in ids:
                cw.insert(0, "pomodoroWidget")
        for v in obj.values():
            patch(v)
    elif isinstance(obj, list):
        for item in obj:
            patch(item)

patch(data)

with open(path, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")

print("  settings.json patched.")
PYEOF
fi

# 3. Add defaults to plugin_settings.json
echo "→ Patching plugin_settings.json ..."
if python3 -c "import json; d=json.load(open('$PLUGIN_SETTINGS')); exit(0 if 'pomodoroWidget' in d else 1)" 2>/dev/null; then
    echo "  pomodoroWidget defaults already present — skipping."
else
    python3 - "$PLUGIN_SETTINGS" <<'PYEOF'
import json, sys

path = sys.argv[1]
with open(path) as f:
    data = json.load(f)

data["pomodoroWidget"] = {
    "enabled": True,
    "workDuration": 25,
    "shortBreakDuration": 5,
    "longBreakDuration": 15,
    "pomodorosUntilLongBreak": 4,
    "autoStartBreak": False,
    "enableSound": False,
    "soundFile": ""
}

with open(path, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")

print("  plugin_settings.json patched.")
PYEOF
fi

echo ""
echo "✓ Installation complete!"
echo ""
echo "  Next steps:"
echo "  1. Restart DankMaterialShell (Super+Shift+R or re-login)"
echo "  2. The Pomodoro widget appears at the start of the center bar"
echo "  3. Click it to open the timer popup"
echo ""
echo "  To configure: open DMS settings → Plugins → Pomodoro Timer"
echo "  Or edit $PLUGIN_SETTINGS directly."
