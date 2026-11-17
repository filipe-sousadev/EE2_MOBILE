This build contains the original game's own files, for the private use of the person who owns the game, on their own computer. It must not be shared or published.

> Note: in practice this build contains **no** files from the original game. The folder it was
> pointed at held only the GOG Galaxy downloader and a Lutris install script, so every picture is
> drawn by code and every number is an estimate (see MECHANICS.md and CREDITS.md).

# Eras de Conquista

An original real-time strategy game for Android phones in landscape (made for the Samsung Galaxy A56),
in the style of epoch-based strategy games: gather food, wood, stone and gold, build a town, advance
through four epochs, train an army and destroy the enemy Town Center. Built with Godot 4.4 (GDScript).

## Run
- Desktop: open this folder with Godot 4.4.1 and press Play, or run `godot --path app`.
- `--screenshot <file.png>`: starts a match, draws about 120 frames, saves the picture and exits.
- `--self-test <file.json>`: plays the core loop with scripted taps (move, gather, train, build, fight, epoch) and writes the results.
- `--soak <seconds>`: developer check, runs a fast match against an idle player and prints the computer's progress.

## Android (Galaxy A56)
- Ready-made, signed APK: `build/ErasDeConquista.apk` (arm64, landscape, package `com.erasdeconquista.jogo`).
  Copy it to the phone (USB or cloud), open it and allow "install unknown apps" for the file manager.
  Or with USB debugging on: `adb install -r build/ErasDeConquista.apk`.
- To rebuild it: `tools/export_android.sh`. It uses only files in `.android-build/` (the Android pieces of
  the Godot 4.4.1 export templates and Google's apksigner, fetched by `tools/fetch_android.py`) and a local
  signing key `.android-build/release.keystore` (keep it: updates must be signed with the same key).
