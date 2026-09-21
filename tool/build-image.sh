#!/usr/bin/env bash
# Builds the web version and then the image that serves it and proxies the API.
#   tool/build-image.sh [tag]      (default managevity:dev)
set -euo pipefail
cd "$(dirname "$0")/.."

tag="${1:-managevity:dev}"
engine="$(command -v podman || command -v docker)"

flutter pub get
flutter gen-l10n
dart run build_runner build --delete-conflicting-outputs
# API_BASE=/api: in the browser everything goes through the proxy in the image (no CORS at the origin).
flutter build web --release --wasm --no-web-resources-cdn --dart-define=API_BASE=/api

"$engine" build -t "$tag" .
echo "Done: $tag — start it with: $engine run --rm -p 8080:8080 $tag"
