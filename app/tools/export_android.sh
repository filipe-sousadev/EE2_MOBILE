#!/bin/sh
# Rebuilds build/ErasDeConquista.apk using only files inside this folder (.android-build) plus Godot 4.4.1.
# Run tools/fetch_android.py first if .android-build is empty.
APP="$(cd "$(dirname "$0")/.." && pwd)"
AB="$APP/.android-build"
GODOT="${GODOT:-/home/ar1m4/.config/craft-anything/engines/godot/Godot_v4.4.1-stable_linux.x86_64}"
JH="${JAVA_HOME:-/home/ar1m4/.config/craft-anything/engines/jdk/jdk-21.0.12.1+1}"
XDG_CONFIG_HOME="$AB/xdg/config" XDG_DATA_HOME="$AB/xdg/data" XDG_CACHE_HOME="$AB/xdg/cache" JAVA_HOME="$JH" \
  "$GODOT" --headless --path "$APP" --export-release "Android" "$APP/build/ErasDeConquista.apk"
