#!/bin/bash
set -e

cd /workspace

# -----------------------
# Ollama persistent setup
# -----------------------
OLLAMA_DIR="/workspace/ollama"
BIN_DIR="/workspace/ollama-bin"
BIN="$BIN_DIR/ollama"

mkdir -p "$OLLAMA_DIR" "$BIN_DIR"

export OLLAMA_MODELS="$OLLAMA_DIR"
export PATH="$BIN_DIR:$PATH"

# -----------------------
# Install Ollama (only once)
# -----------------------
if [ ! -x "$BIN" ]; then
  echo "Installing Ollama..."
  curl -fsSL https://ollama.com/install.sh | sh

  cp /usr/local/bin/ollama "$BIN"
  chmod +x "$BIN"
fi

echo "Ollama version:"
"$BIN" --version

# -----------------------
# Start Ollama
# -----------------------
echo "Starting Ollama..."
"$BIN" serve > /workspace/ollama.log 2>&1 &

sleep 5

# -----------------------
# Install ComfyUI (only once)
# -----------------------
if [ ! -d "/workspace/ComfyUI" ]; then
  echo "Installing ComfyUI..."
  wget https://github.com/ltdrdata/ComfyUI-Manager/raw/main/scripts/install-comfyui-venv-linux.sh -O install-comfyui-venv-linux.sh
  chmod +x install-comfyui-venv-linux.sh
  ./install-comfyui-venv-linux.sh
fi

# -----------------------
# Configure ComfyUI network
# -----------------------
if ! grep -q -- "--listen" /workspace/run_gpu.sh; then
  echo "Configuring ComfyUI for network access..."
  sed -i '$ s/$/ --listen /' /workspace/run_gpu.sh
fi

chmod +x /workspace/run_gpu.sh

# -----------------------
# Install custom nodes (only once)
# -----------------------
cd /workspace/ComfyUI/custom_nodes

[ ! -d "comfyui-model-downloader" ] && git clone https://github.com/dsigmabcn/comfyui-model-downloader.git
[ ! -d "ComfyUI-RunpodDirect" ] && git clone https://github.com/MadiatorLabs/ComfyUI-RunpodDirect.git

# -----------------------
# Start services
# -----------------------
echo "Starting services..."

/start.sh &
/workspace/run_gpu.sh &

echo "✅ Everything is running"

# -----------------------
# KEEP CONTAINER ALIVE
# -----------------------
tail -f /dev/null
