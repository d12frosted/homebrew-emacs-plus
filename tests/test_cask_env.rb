#!/usr/bin/env ruby
# frozen_string_literal: true

# Test suite for CaskEnv PATH injection logic
#
# Run with: ruby tests/test_cask_env.rb

require 'minitest/autorun'
require 'minitest/mock'
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
    ENV.delete("HOMEBREW_PREFIX")
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

  def test_update_site_start_el_does_not_duplicate_path_injection
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

      content = File.read("#{site_lisp}/site-start.el")

      # PATH injection block must not be added again, but the driver
      # options block (issue #964) must be added independently
      assert_equal 1, content.scan("ns-emacs-plus-injected-path").length
      assert_includes content, "native-comp-driver-options"
    end
  end

  def test_update_site_start_el_adds_native_comp_driver_options
    Dir.mktmpdir do |dir|
      app_path = "#{dir}/Emacs.app"
      site_lisp = "#{app_path}/Contents/Resources/site-lisp"
      FileUtils.mkdir_p(site_lisp)

      File.write("#{site_lisp}/site-start.el", <<~ELISP)
        ;;; site-start.el --- Emacs Plus site initialization -*- lexical-binding: t -*-

        (defconst ns-emacs-plus-version 30
          "Major version of Emacs Plus.")

        (provide 'emacs-plus)

        ;;; site-start.el ends here
      ELISP

      Hardware::CPU.mock_arm = true
      CaskEnv.instance_variable_set(:@config, { "inject_path" => true })
      CaskEnv.send(:update_site_start_el, app_path)

      content = File.read("#{site_lisp}/site-start.el")

      # Driver options block resolves gcc at startup and adds -L flags
      assert_includes content, "native-comp-driver-options"
      assert_includes content, "-print-file-name=libemutls_w.a"
      assert_includes content, "native-comp-available-p"
      assert_includes content, "/opt/homebrew/opt/gcc/bin/gcc-[0-9]*"
      assert_includes content, "/opt/homebrew/lib/gcc/current"
      # Block must come before provide so it runs when the file loads
      assert_operator content.index("native-comp-driver-options"), :<,
                      content.index("(provide 'emacs-plus)")
    end
  end

  def test_update_site_start_el_is_idempotent
    Dir.mktmpdir do |dir|
      app_path = "#{dir}/Emacs.app"
      site_lisp = "#{app_path}/Contents/Resources/site-lisp"
      FileUtils.mkdir_p(site_lisp)

      File.write("#{site_lisp}/site-start.el", <<~ELISP)
        ;;; site-start.el
        (defconst ns-emacs-plus-version 30)
        (provide 'emacs-plus)
      ELISP

      CaskEnv.instance_variable_set(:@config, { "inject_path" => true })
      CaskEnv.send(:update_site_start_el, app_path)
      first = File.read("#{site_lisp}/site-start.el")

      CaskEnv.send(:update_site_start_el, app_path)
      assert_equal first, File.read("#{site_lisp}/site-start.el")
    end
  end

  def test_update_site_start_el_handles_missing_file
    Dir.mktmpdir do |dir|
      app_path = "#{dir}/Emacs.app"
      # Don't create site-start.el

      # Should not raise error
      CaskEnv.instance_variable_set(:@config, { "inject_path" => true })
      assert_equal false, CaskEnv.send(:update_site_start_el, app_path)
    end
  end

  def test_update_site_start_el_returns_whether_it_modified
    Dir.mktmpdir do |dir|
      app_path = "#{dir}/Emacs.app"
      site_lisp = "#{app_path}/Contents/Resources/site-lisp"
      FileUtils.mkdir_p(site_lisp)

      File.write("#{site_lisp}/site-start.el", <<~ELISP)
        ;;; site-start.el
        (defconst ns-emacs-plus-version 30)
        (provide 'emacs-plus)
      ELISP

      CaskEnv.instance_variable_set(:@config, { "inject_path" => true })
      assert_equal true, CaskEnv.send(:update_site_start_el, app_path)
      # Second run changes nothing
      assert_equal false, CaskEnv.send(:update_site_start_el, app_path)
    end
  end

  # ===========================================
  # Tests for inject step isolation
  # ===========================================

  # Point config loading at a nonexistent file so inject uses an empty
  # config instead of whatever the developer has in ~/.config/emacs-plus
  def with_empty_build_config
    ENV["HOMEBREW_EMACS_PLUS_BUILD_CONFIG"] = "/nonexistent/build.yml"
    yield
  ensure
    ENV.delete("HOMEBREW_EMACS_PLUS_BUILD_CONFIG")
  end

  def make_site_start(dir)
    app_path = "#{dir}/Emacs.app"
    site_lisp = "#{app_path}/Contents/Resources/site-lisp"
    FileUtils.mkdir_p(site_lisp)
    File.write("#{site_lisp}/site-start.el", <<~ELISP)
      ;;; site-start.el
      (defconst ns-emacs-plus-version 30)
      (provide 'emacs-plus)
    ELISP
    app_path
  end

  def test_inject_continues_when_a_step_fails
    Dir.mktmpdir do |dir|
      app_path = make_site_start(dir)

      # Simulate create_cli_wrapper blowing up inside inject_emacs_app
      # (e.g. Contents/MacOS/bin missing)
      boom = ->(_path) { raise Errno::ENOENT, "#{app_path}/Contents/MacOS/bin/emacs" }

      with_empty_build_config do
        CaskEnv.stub(:inject_emacs_app, boom) do
          # The failure is reported (on stderr) but must not raise out of inject
          assert_output(nil, /Emacs\.app.*failed.*ENOENT/mi) do
            CaskEnv.inject(app_path, "#{dir}/Emacs Client.app")
          end
        end
      end

      # Later steps must still run: site-start.el gets patched
      content = File.read("#{app_path}/Contents/Resources/site-lisp/site-start.el")
      assert_includes content, "ns-emacs-plus-injected-path"
      assert_includes content, "native-comp-driver-options"
    end
  end

  def test_inject_requests_resign_when_a_step_fails
    # A failed step may have modified the bundle before raising (e.g. the
    # plist written but the CLI wrapper not), and the cask re-signs based
    # on inject's return value, so a failure must report true
    Dir.mktmpdir do |dir|
      app_path = make_site_start(dir)

      boom = ->(_path) { raise Errno::ENOENT, "no such file" }

      with_empty_build_config do
        CaskEnv.stub(:inject_emacs_app, boom) do
          needs_resign = nil
          assert_output(nil, /failed/i) do
            needs_resign = CaskEnv.inject(app_path, "#{dir}/Emacs Client.app")
          end
          assert_equal true, needs_resign
        end
      end
    end
  end

  def test_inject_requests_resign_when_only_site_start_changed
    # site-start.el lives inside the bundle, so updating it invalidates
    # the code seal just like the plist steps do; inject must report it
    Dir.mktmpdir do |dir|
      app_path = make_site_start(dir)

      with_empty_build_config do
        CaskEnv.stub(:inject_emacs_app, false) do
          CaskEnv.stub(:inject_emacs_client_app, false) do
            assert_equal true, CaskEnv.inject(app_path, "#{dir}/Emacs Client.app")
          end
        end
      end
    end
  end

  def test_inject_survives_real_cli_wrapper_failure
    # End-to-end version of the motivating failure: an Emacs.app without
    # Contents/MacOS/bin makes create_cli_wrapper hit a genuine
    # Errno::ENOENT inside the real inject_emacs_app
    Dir.mktmpdir do |dir|
      app_path = make_site_start(dir)

      with_empty_build_config do
        with_fake_prefix do
          assert_output(nil, /ENOENT/i) do
            assert_equal true, CaskEnv.inject(app_path, "#{dir}/Emacs Client.app")
          end
        end
      end

      content = File.read("#{app_path}/Contents/Resources/site-lisp/site-start.el")
      assert_includes content, "ns-emacs-plus-injected-path"
      assert_includes content, "native-comp-driver-options"
    end
  end

  def test_create_cli_wrapper_reports_whether_it_wrote
    Dir.mktmpdir do |dir|
      app_path = "#{dir}/Emacs.app"
      FileUtils.mkdir_p("#{app_path}/Contents/MacOS/bin")

      assert_output(/Creating CLI wrapper/) do
        assert_equal true, CaskEnv.send(:create_cli_wrapper, app_path)
      end
      # Second run is a no-op
      assert_equal false, CaskEnv.send(:create_cli_wrapper, app_path)
    end
  end

  # ===========================================
  # Tests for native_comp_env (LSEnvironment vars)
  # ===========================================

  def test_native_comp_env_does_not_include_cc
    # Regression for #939: CC must never be injected into LSEnvironment.
    # Emacs native compilation does not read CC (libgccjit resolves its
    # driver via PATH/GCC_EXEC_PREFIX), so injecting CC=gcc-NN had no effect
    # on compilation while leaking into every child process of GUI Emacs
    # (terminals, compile, eshell), breaking builds that expect clang.
    CaskEnv.stub(:build_library_path, "/opt/homebrew/lib/gcc/current") do
      env = CaskEnv.send(:native_comp_env)
      refute_includes env.keys, "CC"
    end
  end

  def test_native_comp_env_includes_library_path
    CaskEnv.stub(:build_library_path, "/opt/homebrew/lib/gcc/current") do
      env = CaskEnv.send(:native_comp_env)
      assert_equal "/opt/homebrew/lib/gcc/current", env["LIBRARY_PATH"]
    end
  end

  def test_native_comp_env_omits_empty_library_path
    CaskEnv.stub(:build_library_path, "") do
      env = CaskEnv.send(:native_comp_env)
      refute_includes env.keys, "LIBRARY_PATH"
    end
  end

  # ===========================================
  # Tests for gcc-based emutls lookup (PR #963 ported to install-time injection)
  # ===========================================

  # Run a block with HOMEBREW_PREFIX pointing at a fresh tempdir
  def with_fake_prefix
    Dir.mktmpdir do |dir|
      ENV["HOMEBREW_PREFIX"] = dir
      yield dir
    ensure
      ENV.delete("HOMEBREW_PREFIX")
    end
  end

  # Create a fake versioned gcc driver that answers -print-file-name with
  # the given output (gcc echoes the bare file name back when it cannot
  # find the requested library)
  def make_fake_gcc(prefix, version, output)
    bin = File.join(prefix, "opt/gcc/bin")
    FileUtils.mkdir_p(bin)
    gcc = File.join(bin, "gcc-#{version}")
    File.write(gcc, "#!/bin/sh\necho '#{output}'\n")
    File.chmod(0o755, gcc)
    gcc
  end

  def make_cellar_emutls(prefix, gcc_version)
    lib_dir = File.join(prefix, "Cellar/gcc/#{gcc_version}/lib/gcc/current/gcc/aarch64-apple-darwin24/#{gcc_version.split('.').first}")
    FileUtils.mkdir_p(lib_dir)
    File.write(File.join(lib_dir, "libemutls_w.a"), "")
    lib_dir
  end

  def test_find_gcc_executable_returns_nil_without_gcc
    with_fake_prefix do
      assert_nil CaskEnv.send(:find_gcc_executable)
    end
  end

  def test_find_gcc_executable_picks_highest_version
    with_fake_prefix do |prefix|
      make_fake_gcc(prefix, 15, "")
      gcc16 = make_fake_gcc(prefix, 16, "")
      assert_equal gcc16, CaskEnv.send(:find_gcc_executable)
    end
  end

  def test_find_gcc_executable_ignores_non_driver_binaries
    with_fake_prefix do |prefix|
      gcc = make_fake_gcc(prefix, 16, "")
      # gcc-ar-16 style wrappers must not be picked up as the driver
      ar = File.join(File.dirname(gcc), "gcc-ar-16")
      File.write(ar, "#!/bin/sh\n")
      File.chmod(0o755, ar)
      assert_equal gcc, CaskEnv.send(:find_gcc_executable)
    end
  end

  def test_find_emutls_dir_uses_gcc_print_file_name
    with_fake_prefix do |prefix|
      lib_dir = make_cellar_emutls(prefix, "16.1.0")
      make_fake_gcc(prefix, 16, File.join(lib_dir, "libemutls_w.a"))
      assert_equal lib_dir, CaskEnv.send(:find_emutls_dir)
    end
  end

  def test_find_emutls_dir_normalizes_gcc_answer
    with_fake_prefix do |prefix|
      lib_dir = make_cellar_emutls(prefix, "16.1.0")
      # gcc reports the path relative to its bin dir, e.g. .../bin/../lib/...
      cellar = File.join(prefix, "Cellar/gcc/16.1.0")
      unresolved = File.join(cellar, "bin/..", lib_dir.delete_prefix("#{cellar}/"), "libemutls_w.a")
      FileUtils.mkdir_p(File.join(cellar, "bin"))
      make_fake_gcc(prefix, 16, unresolved)
      assert_equal lib_dir, CaskEnv.send(:find_emutls_dir)
    end
  end

  def test_find_emutls_dir_prefers_gcc_answer_over_glob
    with_fake_prefix do |prefix|
      # Two gcc versions in the Cellar: the glob could pick either, but the
      # driver's own answer must win
      make_cellar_emutls(prefix, "15.2.0")
      current = make_cellar_emutls(prefix, "16.1.0")
      make_fake_gcc(prefix, 16, File.join(current, "libemutls_w.a"))
      assert_equal current, CaskEnv.send(:find_emutls_dir)
    end
  end

  def test_find_emutls_dir_falls_back_to_glob_when_gcc_cannot_find_it
    with_fake_prefix do |prefix|
      # gcc echoes the bare name back when it cannot find the library
      make_fake_gcc(prefix, 16, "libemutls_w.a")
      lib_dir = make_cellar_emutls(prefix, "16.1.0")
      assert_equal lib_dir, CaskEnv.send(:find_emutls_dir)
    end
  end

  def test_find_emutls_dir_falls_back_to_glob_without_gcc
    with_fake_prefix do |prefix|
      lib_dir = make_cellar_emutls(prefix, "16.1.0")
      assert_equal lib_dir, CaskEnv.send(:find_emutls_dir)
    end
  end

  def test_find_emutls_dir_returns_nil_when_not_found
    with_fake_prefix do
      assert_nil CaskEnv.send(:find_emutls_dir)
    end
  end

  def test_build_library_path_order_and_contents
    with_fake_prefix do |prefix|
      lib_dir = make_cellar_emutls(prefix, "16.1.0")
      make_fake_gcc(prefix, 16, File.join(lib_dir, "libemutls_w.a"))
      parts = CaskEnv.send(:build_library_path).split(":")
      # Mirrors the LIBRARY_PATH built in build-app.yml (PR #963):
      # emutls dir first, then gcc, libgccjit and prefix lib dirs
      assert_equal [lib_dir,
                    "#{prefix}/lib/gcc/current",
                    "#{prefix}/opt/libgccjit/lib/gcc/current",
                    "#{prefix}/lib"], parts
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
