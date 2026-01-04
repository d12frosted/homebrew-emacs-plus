# mac-font-use-typo-metrics

Fixes line height calculation for CJK fonts by reading typographic metrics from the OS/2 font table instead of the hhea table.

## When to Use This Patch

Use this patch if you experience:
- Partial screen rendering in vterm with mixed CJK and English text
- Text lines getting clipped or overlapping
- Misaligned content in terminal emulators or other pixel-sensitive modes

These issues occur because Emacs calculates incorrect line heights for fonts where the hhea and OS/2 tables have different metrics. vterm and similar modes depend on accurate line heights for positioning.

## Caveat

This patch may cause **reduced line height** with some Latin-only fonts (e.g., PragmataPro) that don't set the USE_TYPO_METRICS flag. Symptoms include:
- Text appearing cramped vertically
- Symbols tied to the top of the line
- Mode line elements appearing higher than expected

If you don't use CJK text or don't experience the rendering issues described above, you probably don't need this patch.

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
