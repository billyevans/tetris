# Tetris

![Tetris CI](https://github.com/billyevans/tetris/actions/workflows/ci.yml/badge.svg)

Tetris written in Zig, using the raylib library for graphics.

## Installation

### Prerequisites

This project requires:
- Zig (0.13.0 or newer)
- raylib

### Install Dependencies

#### macOS
```bash
brew install raylib
```

#### Ubuntu/Debian
```bash
sudo apt-get update
sudo apt-get install -y libasound2-dev libx11-dev libxrandr-dev libxi-dev libgl1-mesa-dev libglu1-mesa-dev libxcursor-dev libxinerama-dev
git clone https://github.com/raysan5/raylib.git raylib
cd raylib
mkdir build && cd build
cmake -DBUILD_SHARED_LIBS=ON ..
make
sudo make install
sudo ldconfig
```

## Usage

### Run the Game
```bash
zig build run
```

### Run Tests
```bash
# Run all tests
zig build test
```

## CI/CD

This project uses GitHub Actions for continuous integration. The workflow automatically builds and tests the game on both macOS and Ubuntu environments.

The CI pipeline runs on:
- Every push to any branch
- Every pull request

## Game Controls

- Left/Right Arrow: Move piece horizontally
- Down Arrow: Soft drop
- Space: Hard drop
- Up Arrow or Z: Rotate clockwise
- Ctrl: Rotate counterclockwise
- F10: Pause game
