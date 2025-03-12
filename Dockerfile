FROM ubuntu:latest

ARG ARCH
ENV TARGET_ARCH=${ARCH}
# Install essential tools
RUN apt-get update && apt-get install -y \
    git \
    build-essential \
    cmake \
    wget \
    curl \
    sudo \
    libasound2-dev \
    libx11-dev \
    libxrandr-dev \
    libxi-dev \
    libgl1-mesa-dev \
    libglu1-mesa-dev \
    libxcursor-dev \
    libxinerama-dev

# Install Zig
RUN mkdir -p /opt/zig
WORKDIR /opt/zig
RUN wget "https://ziglang.org/download/0.13.0/zig-linux-$TARGET_ARCH-0.13.0.tar.xz" \
    && tar -xf "zig-linux-$TARGET_ARCH-0.13.0.tar.xz" \
    && mv zig-linux-$TARGET_ARCH-0.13.0/* . \
    && rm -rf zig-linux-$TARGET_ARCH-0.13.0 zig-linux-$TARGET_ARCH-0.13.0.tar.xz

# Add Zig to PATH
ENV PATH="/opt/zig:${PATH}"

# Install raylib as a static library (which may avoid the compatibility issues)
WORKDIR /tmp
RUN git clone https://github.com/raysan5/raylib.git raylib \
    && cd raylib \
    && mkdir build && cd build \
    && cmake -DBUILD_SHARED_LIBS=OFF \
             -DCMAKE_BUILD_TYPE=Release \
             -DCMAKE_C_FLAGS="-fPIC" \
             -DCMAKE_INSTALL_PREFIX=/usr/local \
             .. \
    && make \
    && make install \
    && ldconfig

# Create a working directory for the project
WORKDIR /app

# We'll mount the project directory here when running the container
CMD ["bash"]
