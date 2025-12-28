#!/usr/bin/env ruby
# frozen_string_literal: true

# Test suite for AppleScript escaping logic used in Emacs Client.app
#
# Run with: ruby tests/test_applescript_escaping.rb
# Or run all tests: ruby tests/test_applescript_escaping.rb

require 'minitest/autorun'
require 'tempfile'
require 'open3'

# Extract the escaping method for testing without loading Homebrew dependencies
module AppleScriptEscaping
  # Escape a string for embedding in an AppleScript double-quoted string
  # that will be passed to `do shell script` with single-quoted arguments.
  #
  # The escaping handles two layers:
  # 1. Shell: single quotes need '\'' idiom (end quote, escaped quote, start quote)
  # 2. AppleScript: backslashes and double quotes need escaping in double-quoted strings
  #
  # Note: We use block form for gsub to avoid special meaning of \& and \' in
  # replacement strings (which would cause incorrect substitutions).
  def self.escape_for_applescript_shell(str)
    # First escape single quotes for shell: ' -> '\''
    shell_escaped = str.to_s.gsub("'") { "'\\''" }
    # Then escape backslashes and double quotes for AppleScript: \ -> \\, " -> \"
    shell_escaped.gsub('\\') { '\\\\' }.gsub('"') { '\\"' }
  end
end

class TestAppleScriptEscaping < Minitest::Test
  def escape(str)
    AppleScriptEscaping.escape_for_applescript_shell(str)
  end

  # ===========================================
  # Unit tests for the escaping function
  # ===========================================

  def test_simple_path_unchanged
    # Simple paths without special characters should pass through
    assert_equal "/usr/bin:/bin:/usr/local/bin", escape("/usr/bin:/bin:/usr/local/bin")
  end

  def test_path_with_spaces
    # Spaces are fine in AppleScript strings
    assert_equal "/Users/John Doe/bin", escape("/Users/John Doe/bin")
  end

  def test_path_with_single_quote
    # Single quotes need shell escaping '\'' which then needs AppleScript escaping
    # Shell: ' -> '\''
    # AppleScript: '\'' -> '\\''
    result = escape("/path/with'quote")
    assert_equal "/path/with'\\\\''quote", result
  end

  def test_path_with_double_quote
    # Double quotes need AppleScript escaping
    result = escape('/path/with"quote')
    assert_equal '/path/with\\"quote', result
  end

  def test_path_with_backslash
    # Backslashes need AppleScript escaping
    result = escape('/path/with\\backslash')
    assert_equal '/path/with\\\\backslash', result
  end

  def test_path_with_all_special_chars
    # Test combination of all special characters
    # Input: /a'b"c\d (single quote, double quote, backslash)
    input = "/a'b\"c\\d"
    result = escape(input)
    # Escaping steps:
    # 1. Shell escape ': /a'\''b"c\d (introduces one backslash)
    # 2. AppleScript escape \: both backslashes become \\
    #    -> /a'\\''b"c\\d
    # 3. AppleScript escape ": " becomes \"
    #    -> /a'\\''b\"c\\d
    #
    # In Ruby notation: two backslashes = \\\\, one backslash = \\
    expected = "/a'\\\\''b\\\"c\\\\d"
    assert_equal expected, result
  end

  def test_multiple_single_quotes
    result = escape("it's Bob's path")
    # Each ' becomes '\\''
    assert_equal "it'\\\\''s Bob'\\\\''s path", result
  end

  def test_empty_string
    assert_equal "", escape("")
  end

  def test_only_special_chars
    # Input: single quote, double quote, backslash
    input = "'\"\\"
    result = escape(input)
    # Expected: '\\'' (escaped single quote) + \\" (escaped double quote) + \\\\ (escaped backslash)
    expected = "'\\\\''\\\"\\\\"
    assert_equal expected, result
  end

  # ===========================================
  # Integration tests - verify AppleScript compiles
  # ===========================================

  def test_applescript_compiles_with_simple_path
    assert_applescript_compiles("/usr/bin:/bin")
  end

  def test_applescript_compiles_with_homebrew_path
    assert_applescript_compiles("/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin")
  end

  def test_applescript_compiles_with_single_quote
    assert_applescript_compiles("/path/with'quote:/bin")
  end

  def test_applescript_compiles_with_double_quote
    assert_applescript_compiles('/path/with"quote:/bin')
  end

  def test_applescript_compiles_with_backslash
    assert_applescript_compiles('/path/with\\backslash:/bin')
  end

  def test_applescript_compiles_with_complex_path
    # Simulate a complex PATH that might exist on some systems
    assert_applescript_compiles(%q{/Users/John's Mac/bin:/path/with"quotes:/weird\\path:/normal/bin})
  end

  def test_applescript_compiles_with_unicode
    assert_applescript_compiles("/Users/José/bin:/Users/日本語/bin")
  end

  # ===========================================
  # End-to-end tests - verify shell receives correct value
  # ===========================================

  def test_shell_receives_correct_simple_path
    assert_shell_receives("/usr/bin:/bin")
  end

  def test_shell_receives_correct_path_with_single_quote
    assert_shell_receives("/path/with'quote")
  end

  def test_shell_receives_correct_path_with_double_quote
    assert_shell_receives('/path/with"quote')
  end

  def test_shell_receives_correct_path_with_backslash
    assert_shell_receives('/path/with\\backslash')
  end

  def test_shell_receives_correct_complex_path
    assert_shell_receives(%q{/a'b"c\d:/normal/path})
  end

  private

  # Helper: Generate AppleScript source and verify it compiles
  def assert_applescript_compiles(path)
    escaped = escape(path)
    script = generate_applescript(escaped)

    Tempfile.create(['test', '.applescript']) do |f|
      f.write(script)
      f.flush

      Dir.mktmpdir do |dir|
        app_path = File.join(dir, "Test.app")
        stdout, stderr, status = Open3.capture3("osacompile", "-o", app_path, f.path)

        assert status.success?,
          "AppleScript compilation failed for path: #{path.inspect}\n" \
          "Escaped as: #{escaped.inspect}\n" \
          "Error: #{stderr}"
      end
    end
  end

  # Helper: Compile and run AppleScript, verify shell receives the original path
  def assert_shell_receives(original_path)
    escaped = escape(original_path)
    # Create a script that sets PATH and echoes it back
    # We use 'env' to show the PATH that was actually set
    script = <<~APPLESCRIPT
      set pathEnv to "PATH='#{escaped}' "
      set result to do shell script pathEnv & "/usr/bin/printenv PATH"
      return result
    APPLESCRIPT

    Tempfile.create(['test', '.applescript']) do |f|
      f.write(script)
      f.flush

      stdout, stderr, status = Open3.capture3("osascript", f.path)

      assert status.success?,
        "AppleScript execution failed for path: #{original_path.inspect}\n" \
        "Escaped as: #{escaped.inspect}\n" \
        "Error: #{stderr}"

      # The shell should receive the original path
      assert_equal original_path, stdout.chomp,
        "Shell received wrong value.\n" \
        "Expected: #{original_path.inspect}\n" \
        "Got: #{stdout.chomp.inspect}\n" \
        "Escaped as: #{escaped.inspect}"
    end
  end

  def generate_applescript(escaped_path)
    <<~APPLESCRIPT
      -- Test AppleScript for compilation
      on run
        set pathEnv to "PATH='#{escaped_path}' "
        try
          do shell script pathEnv & "echo test"
        end try
      end run

      on open theDropped
        repeat with oneDrop in theDropped
          set dropPath to quoted form of POSIX path of oneDrop
          set pathEnv to "PATH='#{escaped_path}' "
          try
            do shell script pathEnv & "echo " & dropPath
          end try
        end repeat
      end open
    APPLESCRIPT
  end
end
