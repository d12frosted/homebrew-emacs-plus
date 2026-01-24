#!/usr/bin/env ruby
# frozen_string_literal: true

# Test suite for CaskEnv PATH injection logic
#
# Run with: ruby tests/test_cask_env.rb

require 'minitest/autorun'
require 'tempfile'
require 'fileutils'

# Mock Hardware::CPU for testing without Homebrew
module Hardware
  module CPU
    class << self
      attr_accessor :mock_arm

      def arm?
        @mock_arm.nil? ? false : @mock_arm
      end
    end
  end
end

require_relative '../Library/CaskEnv'

class TestCaskEnv < Minitest::Test
  def setup
    # Default to ARM architecture for consistent tests
    Hardware::CPU.mock_arm = true
    # Clear any cached config
    CaskEnv.instance_variable_set(:@config, nil)
  end

  def teardown
    # Clean up environment
    ENV.delete("HOMEBREW_EMACS_PLUS_BUILD_CONFIG")
  end

  # ===========================================
  # Tests for inject_path? behavior
  # ===========================================

  def test_inject_path_defaults_to_true_when_no_config
    CaskEnv.instance_variable_set(:@config, nil)
    assert_equal true, CaskEnv.send(:inject_path?)
  end

  def test_inject_path_defaults_to_true_when_empty_config
    CaskEnv.instance_variable_set(:@config, {})
    assert_equal true, CaskEnv.send(:inject_path?)
  end

  def test_inject_path_true_when_explicitly_set
    CaskEnv.instance_variable_set(:@config, { "inject_path" => true })
    assert_equal true, CaskEnv.send(:inject_path?)
  end

  def test_inject_path_false_when_explicitly_set
    CaskEnv.instance_variable_set(:@config, { "inject_path" => false })
    assert_equal false, CaskEnv.send(:inject_path?)
  end

  # ===========================================
  # Tests for native_comp_path
  # ===========================================

  def test_native_comp_path_arm64
    Hardware::CPU.mock_arm = true
    path = CaskEnv.send(:native_comp_path)

    assert_includes path, "/opt/homebrew/bin"
    assert_includes path, "/opt/homebrew/sbin"
    assert_includes path, "/usr/bin"
    assert_includes path, "/bin"
    assert_includes path, "/usr/sbin"
    assert_includes path, "/sbin"
  end

  def test_native_comp_path_intel
    Hardware::CPU.mock_arm = false
    # Clear HOMEBREW_PREFIX to test architecture-based fallback
    original_env = ENV['HOMEBREW_PREFIX']
    ENV.delete('HOMEBREW_PREFIX')

    begin
      path = CaskEnv.send(:native_comp_path)

      assert_includes path, "/usr/local/bin"
      assert_includes path, "/usr/local/sbin"
      assert_includes path, "/usr/bin"
      refute_includes path, "/opt/homebrew"
    ensure
      ENV['HOMEBREW_PREFIX'] = original_env if original_env
    end
  end

  def test_native_comp_path_order
    Hardware::CPU.mock_arm = true
    path = CaskEnv.send(:native_comp_path)
    parts = path.split(':')

    # Homebrew paths should come first
    assert_equal "/opt/homebrew/bin", parts[0]
    assert_equal "/opt/homebrew/sbin", parts[1]
    # System paths after
    assert_equal "/usr/bin", parts[2]
    assert_equal "/bin", parts[3]
  end

  def test_homebrew_prefix_uses_env_when_available
    # Save and set environment variable
    original_env = ENV['HOMEBREW_PREFIX']
    ENV['HOMEBREW_PREFIX'] = '/custom/homebrew'

    begin
      # Since HOMEBREW_PREFIX constant won't be defined in test context,
      # it should fall back to the environment variable
      prefix = CaskEnv.send(:homebrew_prefix)
      assert_equal '/custom/homebrew', prefix
    ensure
      if original_env
        ENV['HOMEBREW_PREFIX'] = original_env
      else
        ENV.delete('HOMEBREW_PREFIX')
      end
    end
  end

  # ===========================================
  # Tests for build_path composition
  # ===========================================

  def test_build_path_without_inject_path
    CaskEnv.instance_variable_set(:@config, { "inject_path" => false })
    Hardware::CPU.mock_arm = true

    path = CaskEnv.send(:build_path)

    # Should only contain native comp paths
    assert_equal CaskEnv.send(:native_comp_path), path
  end

  def test_build_path_with_inject_path_preserves_user_path_first
    CaskEnv.instance_variable_set(:@config, { "inject_path" => true })
    Hardware::CPU.mock_arm = true

    # Set a custom PATH with some unique entries
    original_path = ENV['PATH']
    ENV['PATH'] = "/custom/bin:/another/path:/usr/bin"

    begin
      path = CaskEnv.send(:build_path)
      parts = path.split(':')

      # User paths should come first (preserving order)
      assert_equal "/custom/bin", parts[0]
      assert_equal "/another/path", parts[1]
      assert_equal "/usr/bin", parts[2]

      # Missing native comp paths should be appended
      assert_includes path, "/opt/homebrew/bin"
      assert_includes path, "/opt/homebrew/sbin"

      # /usr/bin is in user path, so should not be duplicated
      assert_equal 1, parts.count("/usr/bin")
    ensure
      ENV['PATH'] = original_path
    end
  end

  def test_build_path_user_path_comes_first
    CaskEnv.instance_variable_set(:@config, { "inject_path" => true })
    Hardware::CPU.mock_arm = true

    # User PATH that contains homebrew paths - user's ordering should be preserved
    original_path = ENV['PATH']
    ENV['PATH'] = "/custom/first:/opt/homebrew/bin:/custom/last"

    begin
      path = CaskEnv.send(:build_path)
      parts = path.split(':')

      # User paths should come first, preserving their order
      assert_equal "/custom/first", parts[0]
      assert_equal "/opt/homebrew/bin", parts[1]
      assert_equal "/custom/last", parts[2]

      # Missing native comp paths should be appended at the end
      homebrew_sbin_index = parts.index("/opt/homebrew/sbin")
      usr_bin_index = parts.index("/usr/bin")

      assert homebrew_sbin_index > 2, "Missing native paths should come after user paths"
      assert usr_bin_index > 2, "Missing native paths should come after user paths"
    ensure
      ENV['PATH'] = original_path
    end
  end

  def test_build_path_preserves_user_path_ordering
    CaskEnv.instance_variable_set(:@config, { "inject_path" => true })
    Hardware::CPU.mock_arm = true

    # User PATH with specific ordering that should be preserved
    original_path = ENV['PATH']
    ENV['PATH'] = "/usr/local/custom:/opt/homebrew/bin:/my/tools:/usr/bin"

    begin
      path = CaskEnv.send(:build_path)
      parts = path.split(':')

      # User's exact ordering should be preserved at the start
      assert_equal "/usr/local/custom", parts[0]
      assert_equal "/opt/homebrew/bin", parts[1]
      assert_equal "/my/tools", parts[2]
      assert_equal "/usr/bin", parts[3]

      # Missing native paths appended (homebrew/sbin, bin, sbin are not in user PATH)
      assert_includes path, "/opt/homebrew/sbin"
      assert_includes path, "/bin"
      assert_includes path, "/sbin"
    ensure
      ENV['PATH'] = original_path
    end
  end

  def test_build_path_removes_duplicates
    CaskEnv.instance_variable_set(:@config, { "inject_path" => true })
    Hardware::CPU.mock_arm = true

    original_path = ENV['PATH']
    # PATH with entries that overlap with native_comp_path
    ENV['PATH'] = "/opt/homebrew/bin:/usr/bin:/custom/bin:/sbin"

    begin
      path = CaskEnv.send(:build_path)
      parts = path.split(':')

      # Each path should appear only once
      assert_equal 1, parts.count("/opt/homebrew/bin")
      assert_equal 1, parts.count("/usr/bin")
      assert_equal 1, parts.count("/sbin")
      assert_equal 1, parts.count("/custom/bin")
    ensure
      ENV['PATH'] = original_path
    end
  end

  def test_build_path_handles_empty_user_path
    CaskEnv.instance_variable_set(:@config, { "inject_path" => true })
    Hardware::CPU.mock_arm = true

    original_path = ENV['PATH']
    ENV['PATH'] = ""

    begin
      path = CaskEnv.send(:build_path)
      # Should just be native_comp_path
      assert_equal CaskEnv.send(:native_comp_path), path
    ensure
      ENV['PATH'] = original_path
    end
  end

  def test_build_path_filters_homebrew_shims
    CaskEnv.instance_variable_set(:@config, { "inject_path" => true })
    Hardware::CPU.mock_arm = true

    original_path = ENV['PATH']
    # Simulate Homebrew's modified PATH with shims
    ENV['PATH'] = "/opt/homebrew/Library/Homebrew/shims/shared:/usr/bin:/bin:/custom/bin"

    begin
      path = CaskEnv.send(:build_path)

      # Homebrew shims should be filtered out
      refute_includes path, "Homebrew/shims"

      # Custom paths should still be included
      assert_includes path, "/custom/bin"
    ensure
      ENV['PATH'] = original_path
    end
  end

  # ===========================================
  # Tests for update_site_start_el
  # ===========================================

  def test_update_site_start_el_adds_path_injection_code
    Dir.mktmpdir do |dir|
      app_path = "#{dir}/Emacs.app"
      site_lisp = "#{app_path}/Contents/Resources/site-lisp"
      FileUtils.mkdir_p(site_lisp)

      # Create initial site-start.el (as CI would create it)
      File.write("#{site_lisp}/site-start.el", <<~ELISP)
        ;;; site-start.el --- Emacs Plus site initialization -*- lexical-binding: t -*-

        (defconst ns-emacs-plus-version 30
          "Major version of Emacs Plus.")

        (provide 'emacs-plus)

        ;;; site-start.el ends here
      ELISP

      CaskEnv.instance_variable_set(:@config, { "inject_path" => true })
      CaskEnv.send(:update_site_start_el, app_path)

      content = File.read("#{site_lisp}/site-start.el")

      # Should have ns-emacs-plus-injected-path computed from EMACS_PLUS_PATH
      assert_includes content, "ns-emacs-plus-injected-path"
      assert_includes content, '(getenv "EMACS_PLUS_PATH")'

      # Should have the PATH injection code
      assert_includes content, "exec-path"
      assert_includes content, '(setenv "PATH" emacs-plus-path)'

      # Should still have the original content
      assert_includes content, "ns-emacs-plus-version"
      assert_includes content, "(provide 'emacs-plus)"
    end
  end

  def test_update_site_start_el_adds_code_regardless_of_inject_path_setting
    # The site-start.el PATH injection code is always added.
    # Whether EMACS_PLUS_PATH is actually set (and thus ns-emacs-plus-injected-path
    # is t at runtime) depends on the inject_path config at install time.
    Dir.mktmpdir do |dir|
      app_path = "#{dir}/Emacs.app"
      site_lisp = "#{app_path}/Contents/Resources/site-lisp"
      FileUtils.mkdir_p(site_lisp)

      File.write("#{site_lisp}/site-start.el", <<~ELISP)
        ;;; site-start.el
        (defconst ns-emacs-plus-version 30)
        (provide 'emacs-plus)
      ELISP

      # Even with inject_path: false, the site-start.el gets the PATH injection code
      # (ns-emacs-plus-injected-path will be nil at runtime since EMACS_PLUS_PATH won't be set)
      CaskEnv.instance_variable_set(:@config, { "inject_path" => false })
      CaskEnv.send(:update_site_start_el, app_path)

      content = File.read("#{site_lisp}/site-start.el")

      # The code is added, but at runtime ns-emacs-plus-injected-path will be nil
      # because EMACS_PLUS_PATH won't be present in the environment
      assert_includes content, "ns-emacs-plus-injected-path"
      assert_includes content, '(getenv "EMACS_PLUS_PATH")'
    end
  end

  def test_update_site_start_el_skips_if_already_has_variable
    Dir.mktmpdir do |dir|
      app_path = "#{dir}/Emacs.app"
      site_lisp = "#{app_path}/Contents/Resources/site-lisp"
      FileUtils.mkdir_p(site_lisp)

      original_content = <<~ELISP
        ;;; site-start.el
        (defconst ns-emacs-plus-version 30)
        (defconst ns-emacs-plus-injected-path t)
        (provide 'emacs-plus)
      ELISP

      File.write("#{site_lisp}/site-start.el", original_content)

      CaskEnv.instance_variable_set(:@config, { "inject_path" => true })
      CaskEnv.send(:update_site_start_el, app_path)

      # Content should be unchanged
      assert_equal original_content, File.read("#{site_lisp}/site-start.el")
    end
  end

  def test_update_site_start_el_handles_missing_file
    Dir.mktmpdir do |dir|
      app_path = "#{dir}/Emacs.app"
      # Don't create site-start.el

      # Should not raise error
      CaskEnv.instance_variable_set(:@config, { "inject_path" => true })
      CaskEnv.send(:update_site_start_el, app_path)
    end
  end

  # ===========================================
  # Tests for escape_for_applescript_shell
  # ===========================================

  def test_escape_for_applescript_shell_handles_single_quotes
    result = CaskEnv.send(:escape_for_applescript_shell, "path'with'quotes")
    # Single quotes escaped for shell (' -> '\''), then backslashes doubled for AppleScript
    # Result: '\'' becomes '\\''
    assert_includes result, "'\\\\''"
  end

  def test_escape_for_applescript_shell_handles_backslashes
    result = CaskEnv.send(:escape_for_applescript_shell, "path\\with\\backslash")
    # Backslashes should be doubled for AppleScript
    assert_includes result, "\\\\"
  end

  def test_escape_for_applescript_shell_handles_normal_path
    result = CaskEnv.send(:escape_for_applescript_shell, "/usr/bin:/opt/homebrew/bin")
    assert_equal "/usr/bin:/opt/homebrew/bin", result
  end
end
