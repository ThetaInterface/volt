#!/bin/bash

set -e

DIALOG_BUILD_DIR="./dialog/build"
GAME_DIR="/home/alpha/Games/volt"

echo "Building..."

cmake --build "$DIALOG_BUILD_DIR"

echo "Moving..."

mv "$DIALOG_BUILD_DIR/text-dialog" "$GAME_DIR/dialog"

echo "Done..."