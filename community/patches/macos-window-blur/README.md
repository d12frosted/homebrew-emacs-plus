# macos-window-blur

Adds configurable background blur support on macOS using CGS APIs

## Compatibility

- Emacs versions: 29, 30, 31

## Maintainer

aaratha

## Usage

Add to your `~/.config/emacs-plus/build.yml`:

```yaml
patches:
  - macos-window-blur
```

Then rebuild Emacs:

```bash
brew reinstall emacs-plus@30
```

## Patch Files

- `emacs-29.patch` - Patch for Emacs 29
- `emacs-30.patch` - Patch for Emacs 30
- `emacs-31.patch` - Patch for Emacs 31
