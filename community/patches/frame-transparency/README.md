# frame-transparency

Adds configurable frame transparency and background blur support on macOS using CGS APIs

## Showcase

Transparency + Blurring (alpha 0.5, blur 20)
![Example](example.png)

## Compatibility

- Emacs versions: 31

## Maintainer

aaratha

## Usage

Add to your `~/.config/emacs-plus/build.yml`:

```yaml
patches:
  - frame-transparency
```

Then rebuild Emacs:

```bash
brew reinstall emacs-plus@31
```

To use the new features, choose which elements should be rendered with transparency

``` emacs-lisp
;; None:
(set-frame-parameter nil 'ns-alpha-elements nil)

;; All:
(set-frame-parameter nil 'ns-alpha-elements '(ns-alpha-all))

;; Choose elements:
;; - Full list: ns-alpha-default (default face/background)
;;              ns-alpha-fringe (fringes + internal border clears)
;;              ns-alpha-box (boxed face outlines)
;;              ns-alpha-stipple (stipple mask background clears)
;;              ns-alpha-relief (3D relief/shadow lines)
;;              ns-alpha-glyphs (glyph background fills like hl-line/region)
(set-frame-parameter nil 'ns-alpha-elements
    '(ns-alpha-default ns-alpha-fringe ns-alpha-glyphs)) ;; e.g.
```

Then add alpha transparency and blur radius parameters in your config:

``` emacs-lisp
(set-frame-parameter nil 'alpha-background 0.5) 
(set-frame-parameter nil 'ns-background-blur 20)
```

Both features are opt-in via frame parameters (alpha-background and ns-background-blur).

## Example Config

Here is an example of how I use this feature. It works using emacs clients attached to a daemon, or by launching the graphical process normally. This also addresses a common issue where the frame initializes with transparency but no blur effect until a redisplay occurs.

``` emacs-lisp
(defun my/apply-frame-transparency (&optional frame)
  "Apply macOS transparency parameters to FRAME (defaults to selected frame)."
  (with-selected-frame (or frame (selected-frame))
    (set-frame-parameter nil 'alpha-background 0.7)
    (set-frame-parameter nil 'ns-background-blur 30)
    (set-frame-parameter nil 'ns-alpha-elements '(ns-alpha-all))))

;; ns-background-blur must be in default-frame-alist to configure the
;; NSWindow backing material at frame creation time (required for blur).
;; This ensures emacsclient frames inherit it automatically.
(add-to-list 'default-frame-alist '(ns-background-blur . 30))
(add-to-list 'default-frame-alist '(ns-alpha-elements ns-alpha-all))

(add-hook 'after-make-frame-functions #'my/apply-frame-transparency)
(unless (daemonp)
  (add-hook 'window-setup-hook #'my/apply-frame-transparency))

;; Apply transparency immediately for non-daemon graphical startup,
;; where neither after-make-frame-functions nor window-setup-hook fires.
(when (display-graphic-p)
  (my/apply-frame-transparency))
```

## Patch Files

- `emacs-31.patch` - Patch for Emacs 31
