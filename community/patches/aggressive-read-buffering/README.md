# aggressive-read-buffering

Improve processing large quantities of data from tty/pty reads on macOS

## Compatibility

- Emacs versions: 29, 30, 31

## Maintainer

aport

## Usage

Add to your `~/.config/emacs-plus/build.yml`:

```yaml
patches:
  - aggressive-read-buffering
```

Then rebuild Emacs:

```bash
brew reinstall emacs-plus@30
```

## Patch Files

- `emacs-29.patch` - Patch for Emacs 29
- `emacs-30.patch` - Patch for Emacs 30
- `emacs-31.patch` - Patch for Emacs 31
