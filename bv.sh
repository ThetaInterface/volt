#!/bin/bash

set -e

ASSETS_DIR="/home/alpha/projects/Dart/volt/assets"
GAME_DIR="/home/alpha/Games/volt"

mkdir -p "$GAME_DIR/bin/"

echo "Building..."

dart build cli -t bin/main.dart -o app

echo "Copying files..."

mv -f ./app/bundle/bin/main "$GAME_DIR/bin/volt"
cp -r "$ASSETS_DIR/locales" "$GAME_DIR/"

echo "Cleaning..."

rm -rf ./app

echo "Done."