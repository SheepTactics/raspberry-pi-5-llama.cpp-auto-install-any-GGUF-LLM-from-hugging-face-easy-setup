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

mkdir -p "$LLAMA_FOLDER" "$MODELS_DIR"

# ---------------------------------------------------------------------
# System update and build dependencies
# libssl-dev is required so the build can make HTTPS connections to
# HuggingFace for model downloads.
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
# Only written if it does not already exist so user settings are kept.
# ---------------------------------------------------------------------
if [ ! -f "$CONFIG" ]; then
    cat > "$CONFIG" << 'EOF'
# ==========================================================
# CURRENT MODEL
# Paste a HuggingFace URL, publisher/modelname, or a local
# .gguf file path. Models download into Desktop/Llama/models/
#
# HuggingFace URL:    https://huggingface.co/ggml-org/gemma-3-1b-it-GGUF
# Short form:         ggml-org/gemma-3-1b-it-GGUF
# Local file:         /home/pi/Desktop/Llama/models/model.gguf
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
TEMP=0.7

# Max context window in tokens (prompt + response combined).
# Higher uses more RAM. 4096 is comfortable on Pi 5.
CONTEXT=4096

# Max tokens to generate per response. -1 means no limit.
MAX_TOKENS=-1

# Batch size for prompt processing. Higher is faster but uses more RAM.
BATCH_SIZE=512

# Penalises repeating recent tokens. 1.0 = off, 1.1 is a mild nudge.
REPEAT_PENALTY=1.1

# Top-K sampling. Limits token candidates to the K most likely.
TOP_K=40

# Top-P (nucleus) sampling. Cuts off unlikely tail tokens.
TOP_P=0.95

# Min-P sampling. Filters tokens below this fraction of the top token.
MIN_P=0.05

# Random seed. -1 = random each run. Set a number for reproducible output.
SEED=-1

# ----------------------------------------------------------
# REASONING / THINKING SETTINGS
# -1    = skip entirely, safe for all models (default)
# 1024+ = limit thinking to that many tokens (reasoning models only)
# ----------------------------------------------------------
REASONING_BUDGET=-1

# ----------------------------------------------------------
# PERFORMANCE SETTINGS
# ----------------------------------------------------------

# Flash attention - faster inference and lower RAM usage.
# on, off, or auto
FLASH_ATTN=auto

# Lock model weights in RAM to prevent swapping to disk.
# Improves consistency but uses more memory. on or off.
MLOCK=off
EOF
fi

# ---------------------------------------------------------------------
# Personality / system prompt
# Only written if it does not already exist so user edits are kept.
# ---------------------------------------------------------------------
if [ ! -f "$PERSONALITY" ]; then
    cat > "$PERSONALITY" << 'EOF'
You are a helpful AI assistant.
EOF
fi

# ---------------------------------------------------------------------
# Run script - lives in ~/llama.cpp/, not visible on the Desktop.
# .desktop Exec cannot hold complex shell logic, so it points here.
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

# Write a single key=value line, using /tmp to avoid temp files on Desktop
set_val() {
    local tmp
    tmp=$(mktemp /tmp/llama-config.XXXXXX)
    sed "s|^$1=.*|$1=$2|" "$CONFIG" > "$tmp" && mv "$tmp" "$CONFIG"
}

# Replace everything between the installed models markers with a fresh list.
# Scans MODELS_DIR for .gguf files and lists them with their full path.
update_model_list() {
    local list=""
    while IFS= read -r -d '' f; do
        list="${list}# $f"$'\n'
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
REASONING_BUDGET=$(get_val REASONING_BUDGET)
FLASH_ATTN=$(get_val FLASH_ATTN)
MLOCK=$(get_val MLOCK)

if [ ! -f "$BINARY" ]; then
    echo "ERROR: llama-cli not found at $BINARY"
    echo "Re-run setup-llama.sh to rebuild."
    exec bash
    exit 1
fi

if [ -z "$CURRENT_MODEL" ]; then
    echo "ERROR: CURRENT_MODEL is not set in llama-config.txt"
    echo ""
    echo "Set it to a HuggingFace URL, publisher/modelname, or local .gguf path."
    exec bash
    exit 1
fi

# Strip HuggingFace URL down to publisher/modelname for -hf flag
HF_REPO="${CURRENT_MODEL#https://huggingface.co/}"
HF_REPO="${HF_REPO#http://huggingface.co/}"

# Kill any other running llama-cli before launching
pkill -x llama-cli 2>/dev/null && echo "Stopped existing llama-cli session." || true
sleep 1

# Refresh installed models list in config
update_model_list

SYSTEM_PROMPT=$(cat "$PERSONALITY" 2>/dev/null || echo "You are a helpful AI assistant.")

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
    --system-prompt "$SYSTEM_PROMPT"
    --conversation
)

[ "$MLOCK" = "on" ] && INFERENCE_FLAGS+=(--mlock)

# Reasoning budget - reasoning models only (DeepSeek-R1, QwQ, etc.)
# -1    = skip entirely, safe for all models
# 1024+ = limit thinking to that many tokens
[ "$REASONING_BUDGET" != "-1" ] && INFERENCE_FLAGS+=(--reasoning-budget "$REASONING_BUDGET")

# If CURRENT_MODEL is a local file path, use -m. Otherwise treat as HF repo.
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

exec bash
SCRIPT

chmod +x "$RUN_SCRIPT"

# ---------------------------------------------------------------------
# Desktop launcher - inside the Llama folder
# gio set marks it trusted so Pi OS Bookworm does not block it.
# On LXDE/PCManFM an Execute dialog may appear once - choose Execute.
# ---------------------------------------------------------------------
DESKTOP_FILE="$HOME/Desktop/Launch-Llama.desktop"
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
