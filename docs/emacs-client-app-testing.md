# Emacs Client.app Test Scenarios

This document provides comprehensive test scenarios to validate the Emacs Client.app implementation.

## Prerequisites

1. Install emacs-plus@30 with the Emacs Client.app:
   ```bash
   brew install emacs-plus@30 --with-<your-icon>-icon
   ```

2. Create aliases in /Applications:
   ```bash
   # Get the prefix
   PREFIX=$(brew --prefix emacs-plus@30)

   # Create aliases
   osascript -e "tell application \"Finder\" to make alias file to posix file \"$PREFIX/Emacs.app\" at posix file \"/Applications\" with properties {name:\"Emacs.app\"}"
   osascript -e "tell application \"Finder\" to make alias file to posix file \"$PREFIX/Emacs Client.app\" at posix file \"/Applications\" with properties {name:\"Emacs Client.app\"}"
   ```

3. Create test files:
   ```bash
   mkdir -p ~/emacs-client-tests
   cd ~/emacs-client-tests
   echo "Test file 1" > test1.txt
   echo "Test file 2" > test2.org
   echo "#!/bin/bash\necho 'test'" > test-script.sh
   echo "# Test markdown" > test.md
   touch "test with spaces.txt"
   ```

## Test Scenarios

### Category 1: Basic Application Launch

#### Test 1.1: Launch from Spotlight (No Daemon Running)
**Precondition**: Ensure no Emacs daemon is running
```bash
pkill -f "Emacs.*daemon" || true
ps aux | grep "[E]macs.*daemon"  # Should show nothing
```

**Steps**:
1. Press Cmd+Space to open Spotlight
2. Type "Emacs Client"
3. Press Enter

**Expected Result**:
- ✅ Emacs daemon starts automatically
- ✅ New Emacs frame opens
- ✅ No error messages appear
- ✅ Emacs window comes to foreground

**Verification**:
```bash
ps aux | grep "[E]macs.*daemon"  # Should show Emacs daemon process
```

---

#### Test 1.2: Launch from Dock (Daemon Already Running)
**Precondition**: Daemon is running from Test 1.1

**Steps**:
1. Add Emacs Client to Dock (drag from Applications folder)
2. Click Emacs Client icon in Dock

**Expected Result**:
- ✅ New Emacs frame opens immediately
- ✅ Daemon doesn't restart (check process ID stays same)
- ✅ Frame comes to foreground

**Verification**:
```bash
# Check daemon uptime hasn't reset
ps -p $(pgrep -f "Emacs.*daemon") -o etime
```

---

#### Test 1.3: Launch from Finder (Double-Click App)
**Steps**:
1. Open Finder
2. Navigate to /Applications
3. Double-click "Emacs Client"

**Expected Result**:
- ✅ New Emacs frame opens
- ✅ Application activates

---

### Category 2: File Opening from Finder

#### Test 2.1: Open File with Right-Click Menu
**Precondition**: Daemon is running

**Steps**:
1. Open Finder and navigate to `~/emacs-client-tests/`
2. Right-click `test1.txt`
3. Select "Open With" → "Emacs Client"

**Expected Result**:
- ✅ New Emacs frame opens with `test1.txt` loaded
- ✅ File path shown in mode line
- ✅ File content "Test file 1" is visible
- ✅ Emacs comes to foreground

---

#### Test 2.2: Open File with Spaces in Name
**Steps**:
1. Right-click `test with spaces.txt`
2. Select "Open With" → "Emacs Client"

**Expected Result**:
- ✅ File opens correctly (path escaping works)
- ✅ No "file not found" errors

---

#### Test 2.3: Open Multiple Files Simultaneously
**Steps**:
1. Select `test1.txt`, `test2.org`, and `test.md` (Cmd+Click)
2. Right-click selection
3. Select "Open With" → "Emacs Client"

**Expected Result**:
- ✅ All three files open in the same frame (separate buffers)
- ✅ Can switch between buffers with `C-x b`

**Verification**:
In Emacs, run:
```elisp
M-x ibuffer
```
Should show all three files in buffer list.

---

#### Test 2.4: Set as Default Application
**Steps**:
1. Right-click `test.md`
2. Click "Get Info" (Cmd+I)
3. Under "Open with:", select "Emacs Client"
4. Click "Change All..."
5. Confirm the dialog
6. Close Get Info window
7. Double-click `test.md`

**Expected Result**:
- ✅ File opens in Emacs Client
- ✅ All .md files now show Emacs Client as default app

**Verification**:
Check another .md file - its icon should change to Emacs icon.

---

### Category 3: Drag and Drop

#### Test 3.1: Drag Single File to App Icon (Finder)
**Steps**:
1. Open Finder to `~/emacs-client-tests/`
2. Open Applications folder in another window
3. Drag `test-script.sh` onto "Emacs Client" app icon

**Expected Result**:
- ✅ File opens in new/existing Emacs frame
- ✅ Shell script content is visible

---

#### Test 3.2: Drag Multiple Files to App Icon
**Steps**:
1. Select `test1.txt`, `test2.org`, `test.md`
2. Drag all three onto "Emacs Client" app icon

**Expected Result**:
- ✅ All files open in buffers
- ✅ No duplicate frames created

---

#### Test 3.3: Drag File to Dock Icon
**Precondition**: Emacs Client is in Dock

**Steps**:
1. Drag `test1.txt` to Emacs Client dock icon

**Expected Result**:
- ✅ File opens in Emacs
- ✅ Same behavior as dragging to Finder icon

---

### Category 4: PATH Injection

#### Test 4.1: PATH Contains Homebrew Binaries
**Steps**:
1. Launch Emacs Client from Spotlight
2. In Emacs, run: `M-x shell`
3. In the shell buffer, type:
   ```bash
   echo $PATH
   which git
   which brew
   ```

**Expected Result**:
- ✅ PATH contains `/opt/homebrew/bin` (Apple Silicon) or `/usr/local/bin` (Intel)
- ✅ `which git` shows Homebrew git (if installed)
- ✅ `which brew` shows `/opt/homebrew/bin/brew`

---

#### Test 4.2: Emacsclient Binary is Found
**Steps**:
1. Kill all Emacs processes:
   ```bash
   pkill -f Emacs
   ```
2. Launch Emacs Client from Finder (double-click)
3. Check daemon started successfully

**Expected Result**:
- ✅ Daemon starts (requires PATH to find emacsclient)
- ✅ No "command not found" errors

**Verification**:
```bash
ps aux | grep "[E]macs.*daemon"
# Should show daemon with correct path
```

---

#### Test 4.3: Disable PATH Injection
**Steps**:
1. Set environment variable:
   ```bash
   launchctl setenv EMACS_PLUS_NO_PATH_INJECTION 1
   ```
2. Kill all Emacs processes
3. Launch Emacs Client from Spotlight
4. In Emacs shell, check PATH:
   ```bash
   M-x shell
   echo $PATH
   ```

**Expected Result**:
- ✅ PATH contains only system paths (/usr/bin, /bin, etc.)
- ✅ Homebrew paths are NOT present

**Cleanup**:
```bash
launchctl unsetenv EMACS_PLUS_NO_PATH_INJECTION
```

---

### Category 5: Daemon Management

#### Test 5.1: Auto-Start Daemon When Not Running
**Steps**:
1. Ensure no daemon is running:
   ```bash
   pkill -f "Emacs.*daemon"
   ```
2. Open `test1.txt` with "Open With" → "Emacs Client"

**Expected Result**:
- ✅ Daemon starts automatically
- ✅ File opens in new frame
- ✅ No manual daemon start needed

---

#### Test 5.2: Connect to Existing Daemon
**Precondition**: Start daemon manually
```bash
$(brew --prefix emacs-plus@30)/Emacs.app/Contents/MacOS/Emacs --daemon
```

**Steps**:
1. Note the daemon process ID:
   ```bash
   pgrep -f "Emacs.*daemon"
   ```
2. Open `test2.org` via Emacs Client

**Expected Result**:
- ✅ File opens in existing daemon
- ✅ Process ID hasn't changed (no new daemon)

---

#### Test 5.3: Handle Missing Socket Gracefully
**Steps**:
1. Start daemon
2. Manually remove socket file:
   ```bash
   rm -rf $(lsof -c Emacs | grep server | grep -E -o '/.*server' | head -1)
   ```
3. Try to open file with Emacs Client

**Expected Result**:
- ✅ New daemon starts (or connects after recreation)
- ✅ File opens successfully
- ✅ No crash or hang

---

### Category 6: Application Metadata

#### Test 6.1: Verify Bundle Identifier
**Steps**:
```bash
osascript -e 'id of application "Emacs Client"'
```

**Expected Result**:
```
org.gnu.EmacsClient
```

---

#### Test 6.2: Verify Application Info
**Steps**:
1. Right-click Emacs Client in Finder
2. Click "Get Info"

**Expected Result**:
- ✅ Name: "Emacs Client"
- ✅ Version: Shows correct version (30.2)
- ✅ Copyright: "Copyright © 1989-2025 Free Software Foundation, Inc."
- ✅ Category: Productivity

---

#### Test 6.3: Verify Icon Display
**Steps**:
1. View Emacs Client in Finder (Icon View)
2. Check Dock icon when app is running

**Expected Result**:
- ✅ Shows same icon as Emacs.app
- ✅ Icon is crisp and clear (not default AppleScript icon)

---

#### Test 6.4: Verify Document Type Associations
**Steps**:
```bash
duti -x txt
duti -x org
duti -x sh
```

**Expected Result**:
- ✅ Emacs Client (org.gnu.EmacsClient) appears in the list of apps that can open these files

---

### Category 7: Edge Cases

#### Test 7.1: Open File with Special Characters
**Steps**:
1. Create test file:
   ```bash
   cd ~/emacs-client-tests
   touch "test's & file (copy).txt"
   ```
2. Open with Emacs Client via right-click

**Expected Result**:
- ✅ File opens correctly
- ✅ No shell escaping errors

---

#### Test 7.2: Open Very Long Path
**Steps**:
1. Create deeply nested directory:
   ```bash
   mkdir -p ~/emacs-client-tests/very/long/path/with/many/directories/to/test/path/handling
   echo "Deep file" > ~/emacs-client-tests/very/long/path/with/many/directories/to/test/path/handling/deep.txt
   ```
2. Open the file with Emacs Client

**Expected Result**:
- ✅ File opens successfully
- ✅ Full path shown in mode line

---

#### Test 7.3: Open Non-Existent File Path
**Steps**:
This is harder to test via GUI, but can be tested via command line:
```bash
open -a "Emacs Client" /tmp/nonexistent-file.txt
```

**Expected Result**:
- ✅ Emacs opens with buffer for new file
- ✅ Shows "(New file)" in mode line

---

#### Test 7.4: Rapid Multiple Opens
**Steps**:
1. Quickly double-click 5 different files in succession

**Expected Result**:
- ✅ All files open
- ✅ No duplicate frames
- ✅ No crashes or hangs

---

#### Test 7.5: Open File While Emacs is Busy
**Steps**:
1. Open Emacs Client
2. In Emacs, start a long operation:
   ```elisp
   M-: (dotimes (i 100000) (message "Busy %d" i))
   ```
3. While that's running, open a file via Finder

**Expected Result**:
- ✅ File opens (eventually)
- ✅ Operation doesn't crash
- ✅ Both operations complete

---

### Category 8: Integration with Main Emacs.app

#### Test 8.1: Both Apps Use Same Daemon
**Steps**:
1. Start Emacs.app directly (not Emacs Client)
2. Open a file: `C-x C-f ~/emacs-client-tests/test1.txt`
3. From Finder, open `test2.org` with Emacs Client

**Expected Result**:
- ✅ Both files appear in same Emacs session
- ✅ Can see both buffers with `C-x C-b`
- ✅ Same frame is used (or same daemon at least)

---

#### Test 8.2: Emacsclient Command Line Still Works
**Steps**:
```bash
$(brew --prefix emacs-plus@30)/bin/emacsclient -c ~/emacs-client-tests/test.md
```

**Expected Result**:
- ✅ File opens in frame
- ✅ Same daemon used by Emacs Client.app

---

### Category 9: Cleanup and Removal

#### Test 9.1: Uninstall Emacs Client
**Steps**:
```bash
rm -rf /Applications/Emacs\ Client.app
```

**Expected Result**:
- ✅ App removed from Spotlight
- ✅ No longer appears in "Open With" menus
- ✅ Launch Services cache updates (may need `killall Finder`)

---

## Automated Test Script

Here's a script to run basic automated tests:

```bash
#!/bin/bash
# test-emacs-client.sh

set -e

PREFIX=$(brew --prefix emacs-plus@30)
EMACSCLIENT="$PREFIX/bin/emacsclient"
TEST_DIR="$HOME/emacs-client-tests"

echo "=== Emacs Client.app Test Suite ==="

# Cleanup
echo "Cleaning up old test files..."
pkill -f "Emacs.*daemon" || true
rm -rf "$TEST_DIR"
mkdir -p "$TEST_DIR"

# Create test files
echo "Creating test files..."
cd "$TEST_DIR"
echo "Test 1" > test1.txt
echo "Test 2" > test2.org
echo "Test 3" > "file with spaces.txt"

# Test 1: Check app exists
echo "Test 1: Checking Emacs Client.app exists..."
if [ -d "$PREFIX/Emacs Client.app" ]; then
    echo "✅ PASS: Emacs Client.app found"
else
    echo "❌ FAIL: Emacs Client.app not found"
    exit 1
fi

# Test 2: Check bundle identifier
echo "Test 2: Checking bundle identifier..."
BUNDLE_ID=$(osascript -e 'id of application "Emacs Client"' 2>/dev/null || echo "")
if [ "$BUNDLE_ID" = "org.gnu.EmacsClient" ]; then
    echo "✅ PASS: Correct bundle identifier"
else
    echo "❌ FAIL: Wrong bundle identifier: $BUNDLE_ID"
    exit 1
fi

# Test 3: Launch app and verify daemon starts
echo "Test 3: Testing daemon auto-start..."
open -a "Emacs Client"
sleep 3
if pgrep -f "Emacs.*daemon" > /dev/null; then
    echo "✅ PASS: Daemon started"
else
    echo "❌ FAIL: Daemon did not start"
    exit 1
fi

# Test 4: Open file via command line
echo "Test 4: Opening file with Emacs Client..."
open -a "Emacs Client" "$TEST_DIR/test1.txt"
sleep 2
# Check if file is in buffer list
$EMACSCLIENT -e '(buffer-file-name)' | grep -q "test1.txt"
if [ $? -eq 0 ]; then
    echo "✅ PASS: File opened successfully"
else
    echo "❌ FAIL: File not opened"
    exit 1
fi

# Test 5: Open file with spaces
echo "Test 5: Opening file with spaces in name..."
open -a "Emacs Client" "$TEST_DIR/file with spaces.txt"
sleep 2
$EMACSCLIENT -e '(buffer-file-name)' | grep -q "file with spaces"
if [ $? -eq 0 ]; then
    echo "✅ PASS: File with spaces opened"
else
    echo "❌ FAIL: File with spaces not opened"
    exit 1
fi

# Cleanup
echo "Cleaning up..."
pkill -f "Emacs.*daemon" || true

echo ""
echo "=== Test Suite Complete ==="
echo "✅ All automated tests passed!"
echo ""
echo "Please run manual tests from docs/emacs-client-app-testing.md"
```

## Test Results Template

Use this template to record test results:

```
Test Date: ___________
macOS Version: ___________
Emacs Version: ___________
Architecture: [ ] Intel  [ ] Apple Silicon

| Test ID | Test Name | Status | Notes |
|---------|-----------|--------|-------|
| 1.1 | Launch from Spotlight | [ ] PASS [ ] FAIL | |
| 1.2 | Launch from Dock | [ ] PASS [ ] FAIL | |
| 1.3 | Launch from Finder | [ ] PASS [ ] FAIL | |
| 2.1 | Open with Right-Click | [ ] PASS [ ] FAIL | |
| 2.2 | Open File with Spaces | [ ] PASS [ ] FAIL | |
| 2.3 | Open Multiple Files | [ ] PASS [ ] FAIL | |
| 2.4 | Set as Default App | [ ] PASS [ ] FAIL | |
| 3.1 | Drag to App Icon | [ ] PASS [ ] FAIL | |
| 3.2 | Drag Multiple Files | [ ] PASS [ ] FAIL | |
| 3.3 | Drag to Dock Icon | [ ] PASS [ ] FAIL | |
| 4.1 | PATH Contains Homebrew | [ ] PASS [ ] FAIL | |
| 4.2 | Emacsclient Found | [ ] PASS [ ] FAIL | |
| 4.3 | Disable PATH Injection | [ ] PASS [ ] FAIL | |
| 5.1 | Auto-Start Daemon | [ ] PASS [ ] FAIL | |
| 5.2 | Connect to Existing | [ ] PASS [ ] FAIL | |
| 5.3 | Handle Missing Socket | [ ] PASS [ ] FAIL | |
| 6.1 | Bundle Identifier | [ ] PASS [ ] FAIL | |
| 6.2 | Application Info | [ ] PASS [ ] FAIL | |
| 6.3 | Icon Display | [ ] PASS [ ] FAIL | |
| 6.4 | Document Types | [ ] PASS [ ] FAIL | |
| 7.1 | Special Characters | [ ] PASS [ ] FAIL | |
| 7.2 | Long Path | [ ] PASS [ ] FAIL | |
| 7.3 | Non-Existent File | [ ] PASS [ ] FAIL | |
| 7.4 | Rapid Multiple Opens | [ ] PASS [ ] FAIL | |
| 7.5 | Open While Busy | [ ] PASS [ ] FAIL | |
| 8.1 | Same Daemon as Main App | [ ] PASS [ ] FAIL | |
| 8.2 | CLI Still Works | [ ] PASS [ ] FAIL | |

Overall Result: [ ] ALL PASS [ ] SOME FAILURES

Critical Issues Found:
_______________________________________
_______________________________________

Notes:
_______________________________________
_______________________________________
```
