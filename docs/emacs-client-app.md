# Emacs Client.app Implementation

## Overview

`Emacs Client.app` is a macOS application bundle that provides a user-friendly way to interact with `emacsclient` from Finder, Spotlight, and the Dock. It allows users to:

- Open files in Emacs by right-clicking in Finder and selecting "Open With → Emacs Client"
- Drag and drop files onto the Emacs Client.app icon
- Launch a new Emacs frame from Spotlight or the Dock
- Set Emacs Client as the default application for text files

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

### AppleScript Structure

The AppleScript application implements two handlers:

#### 1. `on open` Handler (File Opening)

Triggered when:
- User right-clicks a file → "Open With → Emacs Client"
- User drags files onto the Emacs Client.app icon
- User sets Emacs Client as default app and double-clicks a file

```applescript
on open theDropped
  repeat with oneDrop in theDropped
    set dropPath to quoted form of POSIX path of oneDrop
    -- PATH injection logic here
    do shell script pathEnv & "#{prefix}/bin/emacsclient -c -a '' -n " & dropPath
  end repeat
  tell application "Emacs" to activate
end open
```

**Key points:**
- Converts macOS file aliases to POSIX paths using `POSIX path of oneDrop`
- Quotes paths with `quoted form of` to handle spaces and special characters
- Uses `emacsclient -c` to create a new frame
- Uses `-a ''` to auto-start Emacs daemon if not running
- Uses `-n` to return immediately without waiting

#### 2. `on run` Handler (Launch Without Files)

Triggered when:
- User launches Emacs Client from Spotlight
- User clicks Emacs Client in the Dock
- User double-clicks Emacs Client in Finder (without files)

```applescript
on run
  -- PATH injection logic here
  do shell script pathEnv & "#{prefix}/bin/emacsclient -c -a '' -n"
  tell application "Emacs" to activate
end run
```

### PATH Injection

The AppleScript respects the `EMACS_PLUS_NO_PATH_INJECTION` environment variable, similar to Emacs.app:

```applescript
set pathInjection to system attribute "EMACS_PLUS_NO_PATH_INJECTION"
if pathInjection is "" then
  set pathEnv to "PATH='#{escaped_path}' "
else
  set pathEnv to ""
end if
```

This ensures that:
- Homebrew-installed binaries are found when launching from Finder/Spotlight
- Users can opt out by setting `EMACS_PLUS_NO_PATH_INJECTION=1`
- The same PATH used during installation is available to emacsclient

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
- **Application Category**: Productivity
- **Display Name**: "Emacs Client"
- **Icon**: Uses the same icon as Emacs.app for visual consistency

## Usage

After installation, users should create aliases in `/Applications`:

```bash
osascript -e 'tell application "Finder" to make alias file to posix file "#{prefix}/Emacs Client.app" at posix file "/Applications" with properties {name:"Emacs Client.app"}'
```

Then users can:

1. **Set as default application**: Right-click any text file → Get Info → Open with → Select "Emacs Client" → Click "Change All..."
2. **Use "Open With"**: Right-click any file → Open With → Emacs Client
3. **Drag and drop**: Drag files onto the Emacs Client.app icon
4. **Launch empty frame**: Open Emacs Client from Spotlight or double-click in Finder

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

### org-protocol:// URLs

The current implementation doesn't handle `org-protocol://` URLs. To add this functionality, an additional handler would be needed:

```applescript
on open location this_URL
  -- Handle org-protocol:// links
  do shell script pathEnv & "#{prefix}/bin/emacsclient -n " & quoted form of this_URL
  tell application "Emacs" to activate
end open location
```

This could be added in a future enhancement if there's user demand.

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

1. Ensure `EMACS_PLUS_NO_PATH_INJECTION` is not set in your environment
2. Check that Emacs.app is installed at the expected location
3. Verify PATH injection is working by examining the AppleScript source in the app bundle

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

To add Emacs Client.app to other emacs-plus formulas (e.g., emacs-plus@29, emacs-plus@31), simply call the method after icon installation:

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

1. **org-protocol:// support**: Add `on open location` handler to `create_emacs_client_app`
2. **Frame reuse logic**: Check if visible frames exist before creating new ones
3. **Custom daemon socket**: Support `server-name` Emacs variable
4. **Error notifications**: Display user-friendly error dialogs using AppleScript
5. **Terminal mode option**: Add preference for `emacsclient -t` vs GUI frames
6. **URL scheme registration**: Register `emacs://` URL scheme for opening files
