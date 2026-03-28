#!/bin/bash
# =====================================================================
# Llama.cpp Installer for Raspberry Pi 5
# Run with: bash setup-llama.sh
# =====================================================================

set -e

LLAMA_DIR="$HOME/llama.cpp"
BINARY="$LLAMA_DIR/build/bin/llama-cli"
LLAMA_FOLDER="$HOME/Desktop/Llama"
MODELS_DIR="$LLAMA_FOLDER/models"
CONFIG="$LLAMA_FOLDER/llama-config.txt"
PERSONALITY="$LLAMA_FOLDER/personality.txt"
RUN_SCRIPT="$LLAMA_DIR/run-llama.sh"
DESKTOP_FILE="$HOME/Desktop/Launch-Llama.desktop"

mkdir -p "$LLAMA_FOLDER" "$MODELS_DIR"

# ---------------------------------------------------------------------
# System update and build dependencies
# libssl-dev is required for HTTPS connections to HuggingFace.
# ---------------------------------------------------------------------
echo "Updating system and installing build tools..."
sudo apt-get update -qq
sudo apt-get install -y git build-essential cmake libssl-dev

# ---------------------------------------------------------------------
# Build llama.cpp
# Checks for HTTPS support in any existing binary and rebuilds if
# missing. Delete ~/llama.cpp/build to force a full rebuild.
# ---------------------------------------------------------------------
NEEDS_BUILD=false

if [ ! -f "$BINARY" ]; then
    NEEDS_BUILD=true
elif "$BINARY" -hf test/test 2>&1 | grep -q "HTTPS is not supported"; then
    echo "Existing binary missing HTTPS support. Rebuilding..."
    rm -rf "$LLAMA_DIR/build"
    NEEDS_BUILD=true
fi

if [ "$NEEDS_BUILD" = true ]; then
    echo ""
    echo "Building llama.cpp (5 to 15 minutes on Pi 5)..."
    if [ ! -d "$LLAMA_DIR" ]; then
        git clone --depth 1 https://github.com/ggml-org/llama.cpp.git "$LLAMA_DIR"
    fi
    cd "$LLAMA_DIR"
    rm -rf build
    cmake -B build -DGGML_NATIVE=ON -DLLAMA_OPENSSL=ON
    cmake --build build --config Release -j"$(nproc)"
    if [ ! -f "$BINARY" ]; then
        echo "ERROR: Build failed. Check output above."
        exit 1
    fi
    echo "Build complete."
else
    echo "llama-cli already built with HTTPS support. Skipping."
fi

# ---------------------------------------------------------------------
# Config file
# ---------------------------------------------------------------------
if [ ! -f "$CONFIG" ]; then
    cat > "$CONFIG" << 'EOF'
# ==========================================================
# CURRENT MODEL
# Paste a HuggingFace URL, publisher/modelname, or a local
# .gguf file path. Models download into Desktop/Llama/models/
# ==========================================================

CURRENT_MODEL=

# ==========================================================
# INSTALLED MODELS (updated automatically on each launch)
# Copy any path below into CURRENT_MODEL to switch models.
# ==========================================================
# === INSTALLED MODELS START ===
# (none yet)
# === INSTALLED MODELS END ===
# ----------------------------------------------------------
# GENERATION SETTINGS
# ----------------------------------------------------------

# CPU threads to use. 4 is safe for Pi 5, try 3 to leave headroom.
THREADS=4

# Sampling temperature. Lower = more focused, higher = more creative.
# 0.0 to 2.0
TEMP=1

# Max context window in tokens (prompt + response combined).
# Higher uses more RAM. 4096 is comfortable on Pi 5.
CONTEXT=4096

# Max tokens to generate per response. -1 means no limit.
MAX_TOKENS=-1

# Batch size for prompt processing. Higher is faster but uses more RAM.
BATCH_SIZE=1024

# Penalises repeating recent tokens. 1.0 = off, 1.1 is a mild nudge.
REPEAT_PENALTY=1.2

# Top-K sampling. Limits token candidates to the K most likely.
TOP_K=40

# Top-P (nucleus) sampling. Cuts off unlikely tail tokens.
TOP_P=0.9

# Min-P sampling. Filters tokens below this fraction of the top token.
MIN_P=0.1

# Random seed. -1 = random each run. Set a number for reproducible output.
SEED=-1

# Reasoning budget. Reasoning models only. 0 = thinking off. 1+ = token cap.
REASONING_BUDGET=0

# ----------------------------------------------------------
# PERFORMANCE SETTINGS
# ----------------------------------------------------------

# Flash attention for faster inference and lower RAM usage. true/false/auto.
FLASH_ATTN=auto

# Lock model weights in RAM to prevent swapping to disk.
# Improves consistency but uses more memory. true/false.
MLOCK=true

# ----------------------------------------------------------
# ADDITIONAL SETTINGS
# ----------------------------------------------------------

# Restricts all output to ASCII blocking emojis if false. true/false.
EMOJI_ALLOW=false

EOF
fi

# ---------------------------------------------------------------------
# Personality / system prompt
# ---------------------------------------------------------------------
if [ ! -f "$PERSONALITY" ]; then
    cat > "$PERSONALITY" << 'EOF'
You are a helpful AI assistant.
EOF
fi

# ---------------------------------------------------------------------
# Run script lives in ~/llama.cpp/ not visible on the Desktop.
# .desktop Exec cannot hold complex shell logic so it points here.
# LLAMA_CACHE tells llama.cpp where to save downloaded HF models.
# The installed models list in the config is refreshed on every launch.
# ---------------------------------------------------------------------
cat > "$RUN_SCRIPT" << 'SCRIPT'
#!/bin/bash
LLAMA_FOLDER="$HOME/Desktop/Llama"
CONFIG="$LLAMA_FOLDER/llama-config.txt"
PERSONALITY="$LLAMA_FOLDER/personality.txt"
MODELS_DIR="$LLAMA_FOLDER/models"
BINARY="$HOME/llama.cpp/build/bin/llama-cli"

# Download HF models into Desktop/Llama/models/ instead of ~/.cache
export LLAMA_CACHE="$MODELS_DIR"

get_val() {
    grep "^$1=" "$CONFIG" | cut -d= -f2- | xargs
}

# Replace everything between the installed models markers with a fresh list.
# Scans MODELS_DIR for .gguf files and lists them with their full path.
# mmproj files are multimodal projection weights, not main models - excluded.
update_model_list() {
    local list=""
    while IFS= read -r -d '' f; do
        [[ "$(basename "$f")" == mmproj-* ]] && continue
        list="${list}# $(basename "$f")"$'\n'
    done < <(find "$MODELS_DIR" -name "*.gguf" -print0 2>/dev/null | sort -z)
    [ -z "$list" ] && list="# (none yet)"$'\n'

    local tmp
    tmp=$(mktemp /tmp/llama-config.XXXXXX)
    awk -v newlist="$list" '
        /^# === INSTALLED MODELS START ===/ { print; print newlist; skip=1; next }
        /^# === INSTALLED MODELS END ===/   { skip=0 }
        !skip
    ' "$CONFIG" > "$tmp" && mv "$tmp" "$CONFIG"
}

# ---------------------------------------------------------------------
# Read config
# ---------------------------------------------------------------------
CURRENT_MODEL=$(get_val CURRENT_MODEL)
THREADS=$(get_val THREADS)
TEMP=$(get_val TEMP)
CONTEXT=$(get_val CONTEXT)
MAX_TOKENS=$(get_val MAX_TOKENS)
BATCH_SIZE=$(get_val BATCH_SIZE)
REPEAT_PENALTY=$(get_val REPEAT_PENALTY)
TOP_K=$(get_val TOP_K)
TOP_P=$(get_val TOP_P)
MIN_P=$(get_val MIN_P)
SEED=$(get_val SEED)
EMOJI_ALLOW=$(get_val EMOJI_ALLOW)
REASONING_BUDGET=$(get_val REASONING_BUDGET)
FLASH_ATTN=$(get_val FLASH_ATTN)
MLOCK=$(get_val MLOCK)

if [ ! -f "$BINARY" ]; then
    echo "ERROR: llama-cli not found at $BINARY"
    echo "Re-run setup-llama.sh to rebuild."
    exec bash
fi

if [ -z "$CURRENT_MODEL" ]; then
    echo "ERROR: CURRENT_MODEL is not set in llama-config.txt"
    echo ""
    echo "Set it to a HuggingFace URL publisher/modelname or local .gguf path."
    exec bash
fi

# If CURRENT_MODEL is just a filename, resolve it to its full path in MODELS_DIR.
# Allows the config to list short names instead of deep snapshot paths.
if [[ "$CURRENT_MODEL" != */* ]]; then
    RESOLVED=$(find "$MODELS_DIR" -name "$CURRENT_MODEL" -not -name "mmproj-*" 2>/dev/null | head -1)
    if [ -z "$RESOLVED" ]; then
        echo "ERROR: Could not find '$CURRENT_MODEL' in $MODELS_DIR"
        exec bash
    fi
    CURRENT_MODEL="$RESOLVED"
fi

# Strip HuggingFace URL down to publisher/modelname for -hf flag
HF_REPO="${CURRENT_MODEL#https://huggingface.co/}"
HF_REPO="${HF_REPO#http://huggingface.co/}"

# Kill any running llama-cli and wait for it to fully exit before launching.
# Skipping the wait can cause mlock to fail if the old process still holds RAM.
if pkill -x llama-cli 2>/dev/null; then
    echo "Stopping existing llama-cli session..."
    sleep 1
    for i in $(seq 1 5); do
        pgrep -x llama-cli > /dev/null 2>&1 || break
        sleep 1
    done
    pkill -9 -x llama-cli 2>/dev/null || true
    sleep 1
fi

# Refresh installed models list in config
update_model_list

INFERENCE_FLAGS=(
    --threads "$THREADS"
    --temp "$TEMP"
    -c "$CONTEXT"
    --n-predict "$MAX_TOKENS"
    -b "$BATCH_SIZE"
    --repeat-penalty "$REPEAT_PENALTY"
    --top-k "$TOP_K"
    --top-p "$TOP_P"
    --min-p "$MIN_P"
    --seed "$SEED"
    --flash-attn "$FLASH_ATTN"
    --system-prompt-file "$PERSONALITY"
    --conversation
)

[ "$MLOCK" = "true" ] && INFERENCE_FLAGS+=(--mlock)

# Reasoning budget - reasoning models only. 0 = off. 1+ = token cap.
INFERENCE_FLAGS+=(--reasoning-budget "$REASONING_BUDGET")

# ---------------------------------------------------------------------
# Emoji control
# Applied via grammar sampling which acts at the token selection level
# before output is produced. EMOJI_ALLOW=false restricts all output to
# printable ASCII (tab newline 0x20-0x7E). The $'...' quoting embeds
# a real newline between the two GBNF rules which is required syntax.
# ---------------------------------------------------------------------
if [ "$EMOJI_ALLOW" = "false" ]; then
    INFERENCE_FLAGS+=(--grammar $'root ::= ascii+\nascii ::= [\\t\\n -~]')
fi

# If CURRENT_MODEL is a local file path use -m. Otherwise treat as HF repo.
if [ -f "$CURRENT_MODEL" ]; then
    echo "================================"
    echo " llama.cpp"
    echo " Model: $(basename "$CURRENT_MODEL")"
    echo "================================"
    echo ""
    "$BINARY" -m "$CURRENT_MODEL" "${INFERENCE_FLAGS[@]}"
else
    echo "================================"
    echo " llama.cpp"
    echo " HuggingFace: $HF_REPO"
    echo " (downloading to Llama/models/ if not cached)"
    echo "================================"
    echo ""
    "$BINARY" -hf "$HF_REPO" "${INFERENCE_FLAGS[@]}"
fi

# Refresh model list again after exit in case new models were downloaded this session
update_model_list

exec bash
SCRIPT

chmod +x "$RUN_SCRIPT"

# ---------------------------------------------------------------------
# Desktop launcher
# gio set marks it trusted so Pi OS Bookworm does not block it.
# On LXDE/PCManFM an Execute dialog may appear once - choose Execute.
# ---------------------------------------------------------------------
cat > "$DESKTOP_FILE" << EOF
[Desktop Entry]
Name=Launch Llama.cpp
Comment=Start llama.cpp chat session
Exec=bash "$RUN_SCRIPT"
Icon=utilities-terminal
Terminal=true
Type=Application
Categories=Utility;
EOF

chmod +x "$DESKTOP_FILE"
gio set "$DESKTOP_FILE" "metadata::trusted" true 2>/dev/null || true

# Clean up any sed temp files left on the Desktop by previous versions
rm -f "$HOME/Desktop"/sed[A-Za-z0-9]*

# ---------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------
echo ""
echo "=============================="
echo " SETUP COMPLETE"
echo "=============================="
echo ""
echo "Desktop:"
echo "  Launch-Llama.desktop     double-click to start"
echo "  Llama/llama-config.txt   set model and settings here"
echo "  Llama/personality.txt    edit the AI system prompt"
echo "  Llama/models/            downloaded models land here"
echo ""
echo "Set CURRENT_MODEL in llama-config.txt to a HuggingFace URL or"
echo "publisher/modelname. Models download into Llama/models/ on first launch."
echo ""
