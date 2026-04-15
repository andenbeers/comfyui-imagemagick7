#!/bin/bash
set -euo pipefail

cd /workspace

echo "========================="
echo "🚀 Starting setup"
echo "========================="

# -----------------------
# Paths
# -----------------------
OLLAMA_DIR="/workspace/ollama"
BIN_DIR="/workspace/ollama-bin"
BIN="$BIN_DIR/ollama"
COMFY_DIR="/workspace/ComfyUI"

mkdir -p "$OLLAMA_DIR" "$BIN_DIR"

export OLLAMA_MODELS="$OLLAMA_DIR"
export PATH="$BIN_DIR:$PATH"

# -----------------------
# Install Ollama
# -----------------------
if [ ! -x "$BIN" ]; then
  echo "📦 Installing Ollama..."

  curl -fsSL https://ollama.com/install.sh | sh

  # Try to locate installed binary
  if [ -f /usr/local/bin/ollama ]; then
    cp /usr/local/bin/ollama "$BIN"
  elif command -v ollama >/dev/null 2>&1; then
    cp "$(command -v ollama)" "$BIN"
  else
    echo "❌ Ollama install failed"
    exit 1
  fi

  chmod +x "$BIN"
fi

echo "🧠 Ollama version:"
"$BIN" --version || { echo "❌ Ollama not working"; exit 1; }

# -----------------------
# Start Ollama
# -----------------------
echo "🧠 Starting Ollama..."

export CUDA_VISIBLE_DEVICES=0   # change if needed
export OLLAMA_NUM_GPU=999
export OLLAMA_GPU_LAYERS=999

"$BIN" serve > /workspace/ollama.log 2>&1 &
OLLAMA_PID=$!

sleep 3

if ! ps -p $OLLAMA_PID > /dev/null; then
  echo "❌ Ollama failed to start"
  tail -n 100 /workspace/ollama.log
  exit 1
fi

echo "✅ Ollama running (PID: $OLLAMA_PID)"

# -----------------------
# Install ComfyUI
# -----------------------
if [ ! -d "$COMFY_DIR" ]; then
  echo "📦 Installing ComfyUI..."

  cd /workspace
  git clone https://github.com/comfyanonymous/ComfyUI.git

  cd "$COMFY_DIR"

  python3 -m venv venv
  source venv/bin/activate

  pip install --upgrade pip
  pip install -r requirements.txt
else
  echo "✅ ComfyUI already installed"
fi

# -----------------------
# Verify ComfyUI
# -----------------------
if [ ! -f "$COMFY_DIR/main.py" ]; then
  echo "❌ ComfyUI install failed!"
  exit 1
fi

# -----------------------
# Custom nodes
# -----------------------
echo "🔌 Installing custom nodes..."
cd "$COMFY_DIR/custom_nodes"

[ ! -d "comfyui-model-downloader" ] && \
  git clone https://github.com/dsigmabcn/comfyui-model-downloader.git

[ ! -d "ComfyUI-RunpodDirect" ] && \
  git clone https://github.com/MadiatorLabs/ComfyUI-RunpodDirect.git

# -----------------------
# Start ComfyUI
# -----------------------
echo "🎨 Starting ComfyUI..."

cd "$COMFY_DIR"
source venv/bin/activate

python main.py --listen 0.0.0.0 --port 8188 \
  > /workspace/comfyui.log 2>&1 &

COMFY_PID=$!

sleep 5

if ! ps -p $COMFY_PID > /dev/null; then
  echo "❌ ComfyUI crashed on startup"
  echo "===== LOGS ====="
  tail -n 200 /workspace/comfyui.log
  exit 1
fi

echo "✅ ComfyUI running (PID: $COMFY_PID)"

# -----------------------
# Final status check
# -----------------------
echo "========================="
echo "🔍 Service Status"
echo "========================="

if ps -p $OLLAMA_PID > /dev/null; then
  echo "🧠 Ollama OK"
else
  echo "❌ Ollama DOWN"
  tail -n 50 /workspace/ollama.log
fi

if ps -p $COMFY_PID > /dev/null; then
  echo "🎨 ComfyUI OK"
else
  echo "❌ ComfyUI DOWN"
  tail -n 50 /workspace/comfyui.log
fi

echo "========================="
echo "🌐 ComfyUI: http://<your-runpod-ip>:8188"
echo "========================="

# -----------------------
# Keep alive
# -----------------------
tail -f /dev/null
