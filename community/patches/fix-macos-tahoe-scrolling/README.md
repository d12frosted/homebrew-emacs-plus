# fix-macos-tahoe-scrolling

Fixes scrolling lag and input handling issues on macOS 26 (Tahoe).

## Problem

macOS 26 (Tahoe) introduced new event processing behavior that causes:
- Scrolling lag and stuttering, especially with trackpad gestures
- Input handling issues when subprocess I/O is involved (e.g., flyspell, eglot)
- Menu bar interaction problems

## Solution

This patch disables two problematic macOS 26 features by registering NSUserDefaults
before the application initializes:
- `NSEventConcurrentProcessingEnabled` → NO
- `NSApplicationUpdateCycleEnabled` → NO

This fix is based on the equivalent patch in [emacs-mac](https://bitbucket.org/mituharu/emacs-mac/)
by Mitsuharu Yamamoto.

## Compatibility

- Emacs versions: 30, 31
- macOS: Only affects macOS 26 (Tahoe) and later; no-op on earlier versions

## Maintainer

d12frosted

## Usage

Add to your `~/.config/emacs-plus/build.yml`:

```yaml
patches:
  - fix-macos-tahoe-scrolling
```

Then rebuild Emacs:

```bash
brew reinstall emacs-plus@30
# or
brew reinstall emacs-plus@31
```

## Verification

The verification is functional: test if trackpad scrolling feels smoother with flyspell, eglot, or other subprocess-heavy configurations.

**Note:** `registerDefaults:` does not persist to the defaults database, so `defaults read` will not show these values. This is by design - it provides runtime defaults without cluttering user preferences.

## Patch Files

- `emacs-30.patch` - Patch for Emacs 30
- `emacs-31.patch` - Patch for Emacs 31

## References

- [homebrew-emacs-plus issue #900](https://github.com/d12frosted/homebrew-emacs-plus/issues/900)
- [emacs-mac patch](https://bitbucket.org/mituharu/emacs-mac/commits/e52ebfd12def25b0f6373ef17c546ebba1be7d39)
