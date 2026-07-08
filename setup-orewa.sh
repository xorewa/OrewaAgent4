#!/usr/bin/env bash
# Combined installer for an OrewaAgentN stack: Hermes agent (isolated ~/.orewaN
# home) + its bundled VS Code panel, installed in one shot.
#
#   ./setup-orewa.sh
#
# Derives the agent id from this repo's directory name (OrewaAgent<N>), so the
# same script is used unchanged by all four forks.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE="$(basename "$REPO")"                     # e.g. OrewaAgent1
N="${BASE#OrewaAgent}"                          # e.g. 1
ID="orewa${N}"                                  # orewa1
HOME_DIR="$HOME/.${ID}"                          # ~/.orewa1
VENV="$REPO/venv"
HERMES_BIN="$VENV/bin/hermes"
WRAPPER="$HOME/.local/bin/${ID}"
EXT="$REPO/editor/vscode"

echo "== OrewaAgent${N} combined install =="
echo "   repo : $REPO"
echo "   home : $HOME_DIR"
echo "   bin  : $WRAPPER  (CLI: '${ID}')"

# 1) Python agent venv ------------------------------------------------------
echo "-- [1/5] creating venv + installing agent (with ACP extras) --"
python3 -m venv "$VENV"
"$VENV/bin/pip" install --quiet --upgrade pip
"$VENV/bin/pip" install --quiet -e "$REPO"'[acp]'

# 2) isolated home + config -------------------------------------------------
echo "-- [2/5] seeding isolated home $HOME_DIR --"
mkdir -p "$HOME_DIR"
if [ ! -f "$HOME_DIR/config.yaml" ] && [ -f "$REPO/config.example.yaml" ]; then
  cp "$REPO/config.example.yaml" "$HOME_DIR/config.yaml"
  echo "   wrote $HOME_DIR/config.yaml (edit model/provider + API key)"
else
  echo "   $HOME_DIR/config.yaml already exists — left untouched"
fi

# 3) CLI wrapper ------------------------------------------------------------
echo "-- [3/5] installing CLI wrapper $WRAPPER --"
mkdir -p "$(dirname "$WRAPPER")"
cat > "$WRAPPER" <<EOF
#!/usr/bin/env bash
# OrewaAgent${N} — isolated Hermes instance bound to $HOME_DIR
unset PYTHONPATH; unset PYTHONHOME
export HERMES_HOME="$HOME_DIR"
exec "$HERMES_BIN" "\$@"
EOF
chmod +x "$WRAPPER"

# 4) build + install the bundled VS Code panel ------------------------------
echo "-- [4/5] building bundled VS Code extension --"
if command -v npm >/dev/null 2>&1; then
  ( cd "$EXT" && npm install --no-audit --no-fund --loglevel=error && npm run package )
  VSIX="$(ls -t "$EXT"/*.vsix 2>/dev/null | head -1 || true)"
  if [ -n "${VSIX:-}" ] && command -v code >/dev/null 2>&1; then
    code --install-extension "$VSIX" --force
    echo "   installed panel: $(basename "$VSIX")"
  else
    echo "   built $(basename "${VSIX:-<none>}"); install manually if 'code' CLI unavailable"
  fi
else
  echo "   npm not found — skipping panel build"
fi

# 5) point the panel at this venv's binary ----------------------------------
echo "-- [5/5] done. In VS Code settings.json set:"
echo "     \"${ID}.path\": \"$HERMES_BIN\""
echo
echo "CLI:   ${ID} \"your prompt\""
echo "Panel: open the '${BASE}' icon in the VS Code activity bar"
