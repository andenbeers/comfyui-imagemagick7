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
# Install Ollama (CUDA build via GitHub)
# -----------------------
echo "📦 Installing Ollama (CUDA build)..."

# Install zstd for extracting .tar.zst
apt-get install -y zstd 2>/dev/null || true

# Get latest version from GitHub API
OLLAMA_VERSION=$(curl -s https://api.github.com/repos/ollama/ollama/releases/latest | grep tag_name | cut -d'"' -f4)
echo "📌 Ollama version: $OLLAMA_VERSION"

# Download the CUDA tarball (not -rocm, not darwin)
curl -L "https://github.com/ollama/ollama/releases/download/${OLLAMA_VERSION}/ollama-linux-amd64.tar.zst" \
  -o /tmp/ollama.tar.zst

# Verify it actually downloaded (not a "Not Found" page)
FILESIZE=$(stat -c%s /tmp/ollama.tar.zst)
if [ "$FILESIZE" -lt 1000000 ]; then
  echo "❌ Ollama download failed (file too small: ${FILESIZE} bytes)"
  exit 1
fi

# Extract to /usr (puts binary at /usr/bin/ollama)
tar --use-compress-program=unzstd -xf /tmp/ollama.tar.zst -C /usr
rm /tmp/ollama.tar.zst

# Copy to workspace bin dir (this is what RunPod actually runs)
cp /usr/bin/ollama "$BIN"
chmod +x "$BIN"

# Verify CUDA linkage
echo "🔍 Verifying CUDA linkage..."
ldd "$BIN" | grep -i cuda || echo "⚠️  No CUDA linkage found in binary — may still work via runtime discovery"

echo "🧠 Ollama version:"
"$BIN" --version || { echo "❌ Ollama not working"; exit 1; }

# -----------------------
# Start Ollama
# -----------------------
echo "🧠 Starting Ollama (GPU mode)..."
export CUDA_VISIBLE_DEVICES=0
export NVIDIA_VISIBLE_DEVICES=all
export NVIDIA_DRIVER_CAPABILITIES=compute,utility
export OLLAMA_FLASH_ATTENTION=1
export LD_LIBRARY_PATH=/usr/local/cuda/lib64:/usr/lib/x86_64-linux-gnu:/usr/local/nvidia/lib64:/usr/local/nvidia/lib:${LD_LIBRARY_PATH:-}

OLLAMA_DEBUG=1 \
"$BIN" serve > /workspace/ollama.log 2>&1 &
OLLAMA_PID=$!
sleep 5

if ! ps -p $OLLAMA_PID > /dev/null; then
  echo "❌ Ollama failed to start"
  tail -n 100 /workspace/ollama.log
  exit 1
fi

# Confirm GPU was picked up
if grep -q "library=cuda" /workspace/ollama.log; then
  echo "✅ Ollama running on GPU (PID: $OLLAMA_PID)"
elif grep -q "library=cpu" /workspace/ollama.log; then
  echo "⚠️  Ollama started but using CPU — check /workspace/ollama.log"
else
  echo "✅ Ollama running (PID: $OLLAMA_PID)"
fi

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
