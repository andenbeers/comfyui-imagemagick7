FROM runpod/pytorch:2.4.0-py3.11-cuda12.4.1-devel-ubuntu22.04
ENV DEBIAN_FRONTEND=noninteractive

# -----------------------
# Install dependencies
# -----------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    pkg-config \
    wget \
    git \
    dos2unix \
    libjpeg-dev \
    libpng-dev \
    libtiff-dev \
    libwebp-dev \
    libde265-dev \
    libheif-dev \
    libx265-dev \
    libjemalloc-dev \
    libtool \
    libltdl-dev \
    libzstd-dev \
    liblqr-1-0-dev \
    libfftw3-dev \
    libxml2-dev \
    libfreetype6-dev \
    liblcms2-dev \
    libopenjp2-7-dev \
    libx11-dev \
    libxext-dev \
    libxrender-dev \
    libxcb1-dev \
    zlib1g-dev \
    liblzma-dev \
    ca-certificates \
    curl \
    && rm -rf /var/lib/apt/lists/*

# -----------------------
# Build ImageMagick 7
# -----------------------
WORKDIR /tmp
RUN wget https://imagemagick.org/archive/releases/ImageMagick-7.1.1-39.tar.xz && \
    tar -xf ImageMagick-7.1.1-39.tar.xz && \
    cd ImageMagick-7.1.1-39 && \
    ./configure --with-modules --enable-shared --with-quantum-depth=16 && \
    make -j"$(nproc)" && \
    make install && \
    ldconfig && \
    cd / && rm -rf /tmp/ImageMagick-7.1.1-39*

# -----------------------
# Install Ollama
# -----------------------
# Install Ollama (binary only, no systemd)
RUN set -euo pipefail && \
    curl -fL https://github.com/ollama/ollama/releases/latest/download/ollama-linux-amd64 \
    -o /usr/local/bin/ollama && \
    chmod +x /usr/local/bin/ollama && \
    file /usr/local/bin/ollama && \
    /usr/local/bin/ollama --version

ENV OLLAMA_MODELS=/workspace/ollama
# -----------------------
# Create workspace folder
# -----------------------
WORKDIR /workspace
RUN mkdir -p /workspace

# -----------------------
# Copy bootstrap script outside /workspace
# -----------------------
COPY comfy-bootstrap.sh /opt/comfy-bootstrap.sh
RUN dos2unix /opt/comfy-bootstrap.sh && chmod +x /opt/comfy-bootstrap.sh

CMD ["/bin/bash", "/opt/comfy-bootstrap.sh"]
