#!/bin/bash

set -e

DIALOG_DIR="./dialog"
OUTPUT_FILE="./dialog.exe"

echo "Building..."

cd "$DIALOG_DIR" && x86_64-w64-mingw32-g++ main.cpp -std=c++17 -lfltk -lcomctl32 -lole32 -luuid -mwindows -static -o "$OUTPUT_FILE"

echo "Moving..."

cd ..

echo "Done."