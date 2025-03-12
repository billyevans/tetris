# Tetris

![Tetris CI](https://github.com/username/tetris/actions/workflows/ci.yml/badge.svg)

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
sudo apt-get install -y libraylib-dev
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
