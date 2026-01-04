# mac-font-use-typo-metrics

Reads typographic metrics from the OS/2 font table to correctly calculate line height for CJK fonts.

## Problem

Without this patch, Emacs may incorrectly render partial screens with mixed CJK and English text. This is especially visible in vterm where line heights can be miscalculated.

## Trade-off

This patch reads font metrics from the OS/2 table instead of the hhea table. While this fixes CJK rendering issues, it may cause problems with some fonts (e.g., PragmataPro) where English text has excessively low line height when no CJK characters are present.

## Compatibility

- Emacs versions: 29, 30, 31

## Maintainer

Dieken

## Origin

Based on code from [railwaycat/emacs-mac](https://github.com/railwaycat/emacs-mac).

## Usage

Add to your `~/.config/emacs-plus/build.yml`:

```yaml
patches:
  - mac-font-use-typo-metrics
```

Then rebuild Emacs:

```bash
brew reinstall emacs-plus@31  # or @29, @30
```

## Patch Files

- `emacs-29.patch` - Patch for Emacs 29
- `emacs-30.patch` - Patch for Emacs 30
- `emacs-31.patch` - Patch for Emacs 31
