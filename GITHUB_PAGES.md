# GitHub Pages setup

The playable web build lives in [`docs/`](docs/). To publish:

1. Create a **public** repo at https://github.com/new named `escort_wing_godot` (no README/license — this repo already has history).
2. Push:
   ```bash
   git push -u origin main
   ```
3. On GitHub: **Settings → Pages → Build and deployment → Deploy from a branch**
   - Branch: `main`
   - Folder: `/docs`
   - Save
4. After ~1 minute, play at **https://whogben.github.io/escort_wing_godot/**

## Update the live build

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --export-release "Web" docs/index.html
git add docs && git commit -m "Update web build" && git push
```

## Test locally (no push needed)

```bash
python3 serve.py
```

Open http://127.0.0.1:8765/ — or press F5 in the Godot editor for native play.
