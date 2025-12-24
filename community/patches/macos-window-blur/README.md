# macos-window-blur

Adds configurable background blur and alpha transparency support on macOS using CGS APIs

## Showcase



## Compatibility

- Emacs versions: 31

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
brew reinstall emacs-plus@31
```

To use the new features, add alpha transparency and blur radius parameters in your config:

``` bash
(set-frame-parameter nil 'alpha-background 0.5) 
(set-frame-parameter nil 'ns-background-blur 20)
```

## Patch Files

- `emacs-31.patch` - Patch for Emacs 31
