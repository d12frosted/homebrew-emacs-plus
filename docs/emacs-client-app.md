# Emacs Client.app Implementation

## Overview

`Emacs Client.app` is a macOS application bundle that provides a user-friendly way to interact with `emacsclient` from Finder, Spotlight, and the Dock. It allows users to:

- Open files in Emacs by right-clicking in Finder and selecting "Open With → Emacs Client"
- Drag and drop files onto the Emacs Client.app icon
- Launch a new Emacs frame from Spotlight or the Dock
- Set Emacs Client as the default application for text files
- Handle `org-protocol://` URLs for org-capture, org-roam, and other integrations

## Why AppleScript?

### The Problem with Shell Scripts

Initially, we attempted to create Emacs Client.app using a simple shell script wrapper. However, **shell scripts cannot receive AppleEvents**, which is how macOS communicates file opening requests from Finder.

When you use "Open With" in Finder or drag files onto an app icon, macOS sends an `application:openFiles:` AppleEvent to the application—not command-line arguments. A shell script as `CFBundleExecutable` will only receive arguments when launched from the command line, making it unsuitable for this use case.

### Approach Comparison

We evaluated four approaches:

| Approach         | Can Handle Finder Events | Complexity | Build Requirements      |
|------------------|--------------------------|------------|-------------------------|
| **Shell Script** | ❌ No                    | Very Low   | None                    |
| **Swift/Binary** | ✅ Yes                   | Very High  | Xcode, Swift compiler   |
| **Automator**    | ✅ Yes                   | High       | AppleScript + Automator |
| **AppleScript**  | ✅ Yes                   | Low        | Built-in `osacompile`   |

**AppleScript was chosen** because it:
- Properly handles the `on open` event for files from Finder
- Can be compiled during installation using the built-in `osacompile` command
- Requires no external dependencies or build tools
- Has proven implementations in the wild ([example](https://github.com/NicholasKirchner/Emacs_Client_For_OSX))

## Implementation Details

### Code Organization

The Emacs Client.app creation logic is implemented as a reusable method `create_emacs_client_app(icons_dir)` in `Library/EmacsBase.rb`. This allows all emacs-plus formulas (emacs-plus@29, emacs-plus@30, etc.) to share the same implementation.

**Usage in a formula:**
```ruby
# After icon installation
create_emacs_client_app(icons_dir)
```

The method handles:
- AppleScript source generation with PATH injection
- Compilation using `osacompile`
- Info.plist metadata configuration
- Custom icon installation

The casks get the same AppleScript from two other places: the cask build jobs in `.github/workflows/build-app.yml` create the app, and the cask postflight (`Library/CaskEnv.rb`) recompiles it to inject the PATH. `tests/test_client_app_script.rb` checks that all copies compile and bring Emacs to the front the same way, so change them together.

### AppleScript Structure

The AppleScript application implements three handlers, plus a helper that brings Emacs to the front:

#### 1. `on open` Handler (File Opening)

Triggered when:
- User right-clicks a file → "Open With → Emacs Client"
- User drags files onto the Emacs Client.app icon
- User sets Emacs Client as default app and double-clicks a file

```applescript
on open theDropped
  repeat with oneDrop in theDropped
    set dropPath to quoted form of POSIX path of oneDrop
    try
      do shell script "PATH='#{escaped_path}' #{opt_prefix}/bin/emacsclient -c -a '' -n " & dropPath
    end try
  end repeat
  my activateEmacs()
end open
```

**Key points:**
- Converts macOS file aliases to POSIX paths using `POSIX path of oneDrop`
- Quotes paths with `quoted form of` to handle spaces and special characters
- Uses `emacsclient -c` to create a new frame
- Uses `-a ''` to auto-start Emacs daemon if not running
- Uses `-n` to return immediately without waiting
- Calls emacsclient through the formula's `opt` path, which survives upgrades, so a copy of the app in `/Applications` keeps working (the casks use `$(brew --prefix)/bin/emacsclient`)

#### 2. `on run` Handler (Launch Without Files)

Triggered when:
- User launches Emacs Client from Spotlight
- User clicks Emacs Client in the Dock
- User double-clicks Emacs Client in Finder (without files)

```applescript
on run
  try
    do shell script "PATH='#{escaped_path}' #{opt_prefix}/bin/emacsclient -c -a '' -n"
  end try
  my activateEmacs()
end run
```

#### 3. `on open location` Handler (org-protocol URLs)

Triggered when:
- Browser extension sends an `org-protocol://` URL
- User clicks an `org-protocol://` link

```applescript
on open location this_URL
  try
    do shell script "PATH='#{escaped_path}' #{opt_prefix}/bin/emacsclient -r -a '' -n " & quoted form of this_URL
  end try
  my activateEmacs()
end open location
```

**Key points:**
- Handles `org-protocol://` URLs registered via `CFBundleURLTypes`
- Uses `-r` to reuse the current frame, and to create one only when the daemon has none. A daemon started by `brew services` or a LaunchAgent has no GUI frame until the first client asks for one, and until then macOS doesn't know it as an app: with plain `-n` the URL lands in an invisible frame, and `activateEmacs` starts a second Emacs.app instead
- Uses `-a ''` to start the daemon if it isn't running, like the other handlers, instead of dropping the URL
- Requires `(require 'org-protocol)` in your Emacs init file

#### 4. `activateEmacs` (Bringing Emacs to the Front)

Each handler ends by calling this helper:

```applescript
on activateEmacs()
  set emacsId to "org.gnu.Emacs"
  try
    tell application id emacsId to activate
  end try
end activateEmacs
```

**Key points:**
- `tell application id` talks to the Emacs process that is already running, usually the daemon that emacsclient just used
- Don't use `open -a Emacs` here. It asks LaunchServices for an Emacs.app by name, and LaunchServices picks the one launched most recently from Finder, the Dock, Spotlight or `open`. A daemon started by `emacsclient -a ''` is never launched that way, so with a second Emacs.app around (a copy in `/Applications`, another `emacs-plus@N`), `open -a` starts that one next to the daemon. See [discussion #1020](https://github.com/d12frosted/homebrew-emacs-plus/discussions/1020)
- The bundle id is kept in a variable on purpose: `osacompile` resolves a literal `application id "..."` at compile time and fails when the app is not installed, e.g. on CI
- If no Emacs is running at all (for example, emacsclient failed), `activate` launches Emacs.app

### PATH Injection

Every emacsclient call runs with `PATH='...'`, captured when the script is generated (when the formula is installed, or in the cask postflight). This way Homebrew-installed binaries are found when the app is launched from Finder or Spotlight. It follows the same rules as the PATH injected into Emacs.app, including the `inject_path` option in `build.yml`; see [Injected PATH](../README.org#injected-path).

### Compilation Process

The formula creates the app using these steps:

1. **Generate AppleScript source** with interpolated paths and PATH variable
2. **Compile with `osacompile`**:
   ```bash
   osacompile -o "Emacs Client.app" emacs-client.applescript
   ```
3. **Modify Info.plist** using `/usr/libexec/PlistBuddy` to add:
   - `CFBundleIdentifier`: `org.gnu.EmacsClient`
   - `CFBundleDocumentTypes`: File type associations for text/code files
   - `LSApplicationCategoryType`: Productivity category
   - Version information and copyright
4. **Replace default droplet icon**:
   - Copy `Emacs.icns` to `applet.icns` in Resources folder
   - Remove `droplet.icns` and `droplet.rsrc` (created by `osacompile`)
   - Remove `Assets.car` (created by `osacompile` on recent macOS versions)
     - On macOS 26+, the system prioritizes icons in Assets.car over .icns files
     - Removing Assets.car forces macOS to use the custom `applet.icns` file
   - Update `CFBundleIconFile` to reference `applet` instead of `droplet`

### Info.plist Metadata

The generated app bundle includes comprehensive metadata:

- **Bundle Identifier**: `org.gnu.EmacsClient` - Required for proper app registration with Launch Services
- **Document Types**: Declares ability to edit text, source code, scripts, and data files
  - `public.text`
  - `public.plain-text`
  - `public.source-code`
  - `public.script`
  - `public.shell-script`
  - `public.data`
- **URL Types**: Registers `org-protocol` URL scheme for org-capture, org-roam, etc.
- **Application Category**: Productivity
- **Display Name**: "Emacs Client"
- **Icon**: Uses the same icon as Emacs.app for visual consistency

## Usage

The casks install the app into `/Applications`. Formula users copy or symlink it there themselves (the formula caveats show how):

```bash
cp -R "$(brew --prefix emacs-plus@31)/Emacs Client.app" /Applications/
```

A copy keeps working after upgrades, since the app calls emacsclient through the formula's `opt` path. Avoid Finder aliases: an alias points at the versioned keg it was made for and stops working once an upgrade replaces it.

Then users can:

1. **Set as default application**: Right-click any text file → Get Info → Open with → Select "Emacs Client" → Click "Change All..."
2. **Use "Open With"**: Right-click any file → Open With → Emacs Client
3. **Drag and drop**: Drag files onto the Emacs Client.app icon
4. **Launch empty frame**: Open Emacs Client from Spotlight or double-click in Finder
5. **Use org-protocol**: Click `org-protocol://` links from browser extensions

### org-protocol Setup

To use org-protocol with Emacs Client.app:

1. Add `(require 'org-protocol)` to your Emacs init file
2. Install a browser extension like [org-capture-extension](https://github.com/nicksellen/org-capture-extension)
3. With a formula, copy Emacs Client.app to `/Applications` for reliable URL handling (the casks already install it there):
   ```bash
   cp -R "$(brew --prefix emacs-plus@31)/Emacs Client.app" /Applications/
   ```
4. Test with a URL like: `org-protocol://capture?template=t&url=https://example.com&title=Test`

For org-roam, see the [org-roam manual](https://www.orgroam.com/manual.html#org_002droam_002dprotocol).

## Daemon Management

The implementation uses `emacsclient -a ''` (empty alternate editor), which:

- Attempts to connect to an existing Emacs daemon
- If no daemon is running, automatically starts one using the same `emacsclient` binary
- Ensures files always open successfully without manual daemon management

This is more reliable than checking daemon status manually, as it handles edge cases like:
- Daemon crashed or was killed
- Socket file exists but daemon isn't running
- Multiple Emacs versions installed

## Limitations

### Environment Variable Access

AppleScript's `do shell script` command runs in a minimal environment. The `$TMPDIR` variable (where Emacs stores server sockets by default) may not be accessible. However, using `-a ''` works around this by letting `emacsclient` itself handle daemon startup with the correct environment.

## Troubleshooting

### Wrong icon displayed (showing default AppleScript droplet icon)

If you see the generic AppleScript droplet icon instead of the Emacs icon:

1. Check which icon file is referenced:
   ```bash
   /usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' "Emacs Client.app/Contents/Info.plist"
   ```
   Should show: `applet`

2. Verify the icon file exists and Assets.car is removed:
   ```bash
   ls -la "Emacs Client.app/Contents/Resources/"
   ```
   Should show `applet.icns`, but NOT `droplet.icns` or `Assets.car`

3. **macOS 26+ specific**: If `Assets.car` exists, it must be removed. On macOS 26 (Tahoe) and later, the system prioritizes icon images embedded in Assets.car over standalone .icns files. The build process removes this file automatically, but if you're manually modifying an existing app:
   ```bash
   rm -f "Emacs Client.app/Contents/Resources/Assets.car"
   touch "Emacs Client.app"  # Update modification timestamp
   ```

4. Reset Launch Services cache:
   ```bash
   /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user
   killall Finder  # Refresh Finder
   ```

5. If the issue persists after reinstall, the build may have failed to properly replace the default icon. Check the build logs for icon-related errors.

### Files don't open when double-clicked

1. Check that Emacs Client is set as the default application for that file type
2. Verify the daemon is running: `ps aux | grep "Emacs.*daemon"`
3. Try launching from command line to see error messages: `open -a "Emacs Client" file.txt`

### "Emacs not found" errors

1. Check that Emacs.app is installed at the expected location
2. Check the emacsclient path and PATH baked into the script: `osadecompile "/Applications/Emacs Client.app/Contents/Resources/Scripts/main.scpt"`

### A second Emacs starts next to the daemon

Older builds brought Emacs to the front with `open -a Emacs`, which could start another Emacs.app (see `activateEmacs` above). Reinstall the formula or upgrade the cask. If you copied `Emacs Client.app` to `/Applications`, copy it again: a copy does not update by itself.

### Daemon won't start automatically

1. Ensure `emacsclient` binary has execute permissions
2. Check that no conflicting Emacs installations are interfering
3. Try manually starting daemon: `#{prefix}/Emacs.app/Contents/MacOS/Emacs --daemon`

## References

- [AppleScript Language Guide - Handlers](https://developer.apple.com/library/archive/documentation/AppleScript/Conceptual/AppleScriptLangGuide/reference/ASLR_control_statements.html#//apple_ref/doc/uid/TP40000983-CH6g-128720)
- [osacompile man page](https://ss64.com/mac/osacompile.html)
- [Handling Apple Events in shell scripts](https://apple.stackexchange.com/questions/387156/can-i-handle-the-apple-event-open-within-a-bash-shell-script-using-osascript-c)
- [Emacs Client AppleScript example](https://github.com/NicholasKirchner/Emacs_Client_For_OSX)
- [Running emacsclient from AppleScript](https://emacs.stackexchange.com/questions/35144/how-to-run-emacsclient-from-applescript)

## Extending to Other Formulas

To add Emacs Client.app to other emacs-plus formulas (e.g., emacs-plus@29, emacs-plus@31, emacs-plus@32), simply call the method after icon installation:

```ruby
def install
  # ... existing installation code ...

  if (build.with? "cocoa") && (build.without? "x11")
    # ... icon installation code ...

    # Create Emacs Client.app
    create_emacs_client_app(icons_dir)

    # Install both apps
    prefix.install "nextstep/Emacs.app"
    prefix.install "nextstep/Emacs Client.app"

    # ... rest of installation ...
  end
end
```

The method automatically uses the correct `prefix`, `version`, and `buildpath` from the formula context.

## Future Enhancements

Potential improvements for future versions:

1. **Frame reuse logic**: Check if visible frames exist before creating new ones
2. **Custom daemon socket**: Support `server-name` Emacs variable
3. **Error notifications**: Display user-friendly error dialogs using AppleScript
4. **Terminal mode option**: Add preference for `emacsclient -t` vs GUI frames
5. **URL scheme registration**: Register `emacs://` URL scheme for opening files
