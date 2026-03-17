#!/bin/bash
# Run from brain-visualizer root: unstage binaries, stage source changes, commit, push.
set -e
cd "$(dirname "$0")"

# Remove stale lock so git can run (e.g. after a killed git process).
if [ -f .git/index.lock ]; then
  echo "Removing stale .git/index.lock (ensure no other git process is running)."
  rm -f .git/index.lock
fi

# Unstage everything then re-add only what we want (avoids touching large binary paths that can trigger SIGKILL).
echo "Unstaging all, then staging only source and config..."
git reset HEAD

echo "Staging source and config changes..."
git add .gitignore \
  godot_source/addons/FeagiCoreIntegration/FeagiCore/Networking/FEAGINetworking.gd \
  rust_extensions/build.py \
  rust_extensions/feagi_data_deserializer/build.sh

# Optional: add if you changed them
for f in .github/workflows/ci.yml rust_extensions/rebuild_and_reload.sh rust_extensions/build_feagi_embedded.sh; do
  if [ -f "$f" ] && ! git diff --quiet -- "$f" 2>/dev/null; then
    git add "$f"
  fi
done

echo "Status before commit:"
git status --short

if [[ "$1" != "-y" && "$1" != "--yes" ]]; then
  echo ""
  read -p "Commit and push? [y/N] " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[yY]$ ]]; then
    echo "Aborted. Run 'git status' and commit manually if needed."
    exit 0
  fi
fi

git commit -m "BV: transport/build/deserializer fixes; ignore FeagiCoreIntegration and addon binaries

- FEAGINetworking: treat Client already registered as success; return false so WebSocket connects for viz data
- build.sh: Linux/Windows copy to target/triple/release; script-dir resolution; --locked; no emoji
- build.py: stop removing FeagiCoreIntegration deserializer dylib in cleanup
- .gitignore: ignore FeagiCoreIntegration and feagi_shared_video addon binaries so they are not committed"

git push

echo "Done."
