#!/bin/bash
set -e

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
# Install Ollama (once)
# -----------------------
if [ ! -x "$BIN" ]; then
  echo "📦 Installing Ollama..."
  curl -fsSL https://ollama.com/install.sh | sh
  cp /usr/local/bin/ollama "$BIN"
  chmod +x "$BIN"
fi

echo "Ollama version:"
"$BIN" --version || true

# -----------------------
# Start Ollama
# -----------------------
echo "🧠 Starting Ollama..."
export CUDA_VISIBLE_DEVICES=0   # ⚠️ change to 1 if your GPU is index 1
export OLLAMA_NUM_GPU=999
export OLLAMA_GPU_LAYERS=999
"$BIN" serve > /workspace/ollama.log 2>&1 &

sleep 5

# -----------------------
# Install ComfyUI (correct way)
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
# Verify install
# -----------------------
if [ ! -f "$COMFY_DIR/main.py" ]; then
  echo "❌ ComfyUI install failed!"
  exit 1
fi

# -----------------------
# Install custom nodes
# -----------------------
echo "🔌 Installing custom nodes..."
cd "$COMFY_DIR/custom_nodes"

[ ! -d "comfyui-model-downloader" ] && git clone https://github.com/dsigmabcn/comfyui-model-downloader.git
[ ! -d "ComfyUI-RunpodDirect" ] && git clone https://github.com/MadiatorLabs/ComfyUI-RunpodDirect.git

# -----------------------
# Start ComfyUI
# -----------------------
echo "🎨 Starting ComfyUI..."

cd "$COMFY_DIR"
source venv/bin/activate

python main.py --listen 0.0.0.0 --port 8188 > /workspace/comfyui.log 2>&1 &

# -----------------------
# Final status
# -----------------------
sleep 5

echo "========================="
echo "✅ ALL SERVICES RUNNING"
echo "🌐 ComfyUI: http://<your-runpod-ip>:8188"
echo "🧠 Ollama running"
echo "========================="

# -----------------------
# Keep container alive
# -----------------------
tail -f /dev/null
