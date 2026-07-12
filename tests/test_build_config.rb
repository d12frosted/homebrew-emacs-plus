#!/usr/bin/env ruby
# frozen_string_literal: true

# Test suite for BuildConfig validation
#
# Run with: ruby tests/test_build_config.rb
#
# This tests that malformed build.yml files produce helpful error messages
# instead of cryptic Ruby errors like "undefined method 'key?' for an instance of String"

require 'minitest/autorun'
require 'tempfile'
require_relative '../Library/BuildConfig'

class TestBuildConfig < Minitest::Test
  # ===========================================
  # Tests for valid configurations
  # ===========================================

  def test_empty_file_returns_empty_config
    with_temp_config("") do |path|
      result = load_config_from_path(path)
      assert_equal({}, result[:config])
      assert_equal path, result[:source]
    end
  end

  def test_valid_icon_string
    with_temp_config("icon: modern-icon") do |path|
      result = load_config_from_path(path)
      assert_equal "modern-icon", result[:config]["icon"]
    end
  end

  def test_valid_icon_hash
    yaml = <<~YAML
      icon:
        url: https://example.com/icon.icns
        sha256: abc123
    YAML
    with_temp_config(yaml) do |path|
      result = load_config_from_path(path)
      assert_equal "https://example.com/icon.icns", result[:config]["icon"]["url"]
      assert_equal "abc123", result[:config]["icon"]["sha256"]
    end
  end

  def test_valid_inject_path_true
    with_temp_config("inject_path: true") do |path|
      result = load_config_from_path(path)
      assert_equal true, result[:config]["inject_path"]
    end
  end

  def test_valid_inject_path_false
    with_temp_config("inject_path: false") do |path|
      result = load_config_from_path(path)
      assert_equal false, result[:config]["inject_path"]
    end
  end

  def test_valid_full_config
    yaml = <<~YAML
      icon: spacemacs
      inject_path: true
    YAML
    with_temp_config(yaml) do |path|
      result = load_config_from_path(path)
      assert_equal "spacemacs", result[:config]["icon"]
      assert_equal true, result[:config]["inject_path"]
    end
  end

  # ===========================================
  # Tests for malformed YAML - the issue from #896
  # ===========================================

  def test_missing_space_after_colon_is_rejected
    # This is the exact issue from #896: "icon:foo" instead of "icon: foo"
    # YAML parses "icon:foo" as a string, not as a key-value pair
    with_temp_config("icon:modern-icon") do |path|
      error = assert_raises(BuildConfig::ConfigurationError) do
        load_config_from_path(path)
      end
      assert_includes error.message, "Expected a YAML mapping"
      assert_includes error.message, "Missing space after colon"
    end
  end

  def test_plain_string_is_rejected
    with_temp_config("just a string") do |path|
      error = assert_raises(BuildConfig::ConfigurationError) do
        load_config_from_path(path)
      end
      assert_includes error.message, "Expected a YAML mapping"
      assert_includes error.message, "String"
    end
  end

  def test_array_is_rejected
    yaml = <<~YAML
      - item1
      - item2
    YAML
    with_temp_config(yaml) do |path|
      error = assert_raises(BuildConfig::ConfigurationError) do
        load_config_from_path(path)
      end
      assert_includes error.message, "Expected a YAML mapping"
      assert_includes error.message, "Array"
    end
  end

  def test_number_is_rejected
    with_temp_config("42") do |path|
      error = assert_raises(BuildConfig::ConfigurationError) do
        load_config_from_path(path)
      end
      assert_includes error.message, "Expected a YAML mapping"
    end
  end

  # ===========================================
  # Tests for invalid field values
  # ===========================================

  def test_invalid_inject_path_string
    # Note: YAML 1.1 treats "yes"/"no" as booleans, so we use a quoted string
    with_temp_config('inject_path: "yes"') do |path|
      error = assert_raises(BuildConfig::ConfigurationError) do
        load_config_from_path(path)
      end
      assert_includes error.message, "Invalid 'inject_path'"
      assert_includes error.message, "Expected: true or false"
    end
  end

  def test_invalid_inject_path_number
    with_temp_config("inject_path: 1") do |path|
      error = assert_raises(BuildConfig::ConfigurationError) do
        load_config_from_path(path)
      end
      assert_includes error.message, "Invalid 'inject_path'"
    end
  end

  def test_invalid_icon_number
    with_temp_config("icon: 123") do |path|
      error = assert_raises(BuildConfig::ConfigurationError) do
        load_config_from_path(path)
      end
      assert_includes error.message, "Invalid 'icon'"
    end
  end

  def test_invalid_icon_hash_missing_url
    yaml = <<~YAML
      icon:
        sha256: abc123
    YAML
    with_temp_config(yaml) do |path|
      error = assert_raises(BuildConfig::ConfigurationError) do
        load_config_from_path(path)
      end
      assert_includes error.message, "both 'url' and 'sha256' are required"
    end
  end

  def test_invalid_icon_hash_missing_sha256
    yaml = <<~YAML
      icon:
        url: https://example.com/icon.icns
    YAML
    with_temp_config(yaml) do |path|
      error = assert_raises(BuildConfig::ConfigurationError) do
        load_config_from_path(path)
      end
      assert_includes error.message, "both 'url' and 'sha256' are required"
    end
  end

  # ===========================================
  # Tests for YAML syntax errors
  # ===========================================

  def test_yaml_syntax_error_bad_indentation
    yaml = <<~YAML
      icon: test
        nested: wrong
    YAML
    with_temp_config(yaml) do |path|
      error = assert_raises(BuildConfig::ConfigurationError) do
        load_config_from_path(path)
      end
      assert_includes error.message, "YAML syntax error"
    end
  end

  def test_yaml_syntax_error_tabs
    with_temp_config("icon:\t\ttabbed") do |path|
      # Tabs in YAML are actually allowed in some contexts
      # but this tests the general YAML parsing
      result = load_config_from_path(path)
      assert_equal "tabbed", result[:config]["icon"]
    end
  end

  # ===========================================
  # Error message quality tests
  # ===========================================

  def test_error_message_includes_file_path
    with_temp_config("invalid:string") do |path|
      error = assert_raises(BuildConfig::ConfigurationError) do
        load_config_from_path(path)
      end
      assert_includes error.message, path
    end
  end

  def test_error_message_is_actionable
    with_temp_config("icon:no-space") do |path|
      error = assert_raises(BuildConfig::ConfigurationError) do
        load_config_from_path(path)
      end
      # Error should tell user what to do
      assert_includes error.message, "Missing space after colon"
      assert_includes error.message, "icon: value"
    end
  end

  # ===========================================
  # Tests for unknown keys
  # ===========================================

  def test_unknown_key_is_rejected
    with_temp_config("unknown_key: value") do |path|
      error = assert_raises(BuildConfig::ConfigurationError) do
        load_config_from_path(path)
      end
      assert_includes error.message, "Unknown configuration key"
      assert_includes error.message, "unknown_key"
      assert_includes error.message, "Valid keys are"
    end
  end

  def test_typo_icn_suggests_icon
    with_temp_config("icn: modern-icon") do |path|
      error = assert_raises(BuildConfig::ConfigurationError) do
        load_config_from_path(path)
      end
      assert_includes error.message, "Unknown configuration key"
      assert_includes error.message, "Did you mean"
      assert_includes error.message, "'icn' -> 'icon'"
    end
  end

  def test_typo_paches_suggests_patches
    with_temp_config("paches:\n  - test") do |path|
      error = assert_raises(BuildConfig::ConfigurationError) do
        load_config_from_path(path)
      end
      assert_includes error.message, "'paches' -> 'patches'"
    end
  end

  def test_typo_icons_suggests_icon
    # Common typo: plural "icons" instead of singular "icon"
    with_temp_config("icons: dragon-plus") do |path|
      error = assert_raises(BuildConfig::ConfigurationError) do
        load_config_from_path(path)
      end
      assert_includes error.message, "Unknown configuration key"
      assert_includes error.message, "'icons' -> 'icon'"
    end
  end

  def test_multiple_unknown_keys
    yaml = <<~YAML
      icon: test
      foo: bar
      baz: qux
    YAML
    with_temp_config(yaml) do |path|
      error = assert_raises(BuildConfig::ConfigurationError) do
        load_config_from_path(path)
      end
      assert_includes error.message, "foo"
      assert_includes error.message, "baz"
    end
  end

  # ===========================================
  # Tests for patches validation
  # ===========================================

  def test_valid_patches_array
    yaml = <<~YAML
      patches:
        - frame-transparency
        - aggressive-read-buffering
    YAML
    with_temp_config(yaml) do |path|
      result = load_config_from_path(path)
      assert_equal ["frame-transparency", "aggressive-read-buffering"], result[:config]["patches"]
    end
  end

  def test_valid_patches_empty_array
    with_temp_config("patches: []") do |path|
      result = load_config_from_path(path)
      assert_equal [], result[:config]["patches"]
    end
  end

  def test_invalid_patches_string
    with_temp_config("patches: frame-transparency") do |path|
      error = assert_raises(BuildConfig::ConfigurationError) do
        load_config_from_path(path)
      end
      assert_includes error.message, "Invalid 'patches'"
      assert_includes error.message, "Expected: array"
    end
  end

  def test_invalid_patches_hash
    yaml = <<~YAML
      patches:
        name: frame-transparency
    YAML
    with_temp_config(yaml) do |path|
      error = assert_raises(BuildConfig::ConfigurationError) do
        load_config_from_path(path)
      end
      assert_includes error.message, "Invalid 'patches'"
    end
  end

  # ===========================================
  # Tests for revision validation
  # ===========================================

  def test_valid_revision_string
    with_temp_config("revision: abc123def456") do |path|
      result = load_config_from_path(path)
      assert_equal "abc123def456", result[:config]["revision"]
    end
  end

  def test_valid_revision_hash
    yaml = <<~YAML
      revision:
        "30": abc123
        "31": def456
    YAML
    with_temp_config(yaml) do |path|
      result = load_config_from_path(path)
      assert_equal "abc123", result[:config]["revision"]["30"]
      assert_equal "def456", result[:config]["revision"]["31"]
    end
  end

  def test_invalid_revision_not_hex
    with_temp_config("revision: not-a-hash") do |path|
      error = assert_raises(BuildConfig::ConfigurationError) do
        load_config_from_path(path)
      end
      assert_includes error.message, "Invalid 'revision'"
      assert_includes error.message, "git commit hash"
    end
  end

  def test_invalid_revision_hash_value_not_hex
    yaml = <<~YAML
      revision:
        "30": not-hex
    YAML
    with_temp_config(yaml) do |path|
      error = assert_raises(BuildConfig::ConfigurationError) do
        load_config_from_path(path)
      end
      assert_includes error.message, "Invalid 'revision.30'"
    end
  end

  def test_invalid_revision_array
    yaml = <<~YAML
      revision:
        - abc123
    YAML
    with_temp_config(yaml) do |path|
      error = assert_raises(BuildConfig::ConfigurationError) do
        load_config_from_path(path)
      end
      assert_includes error.message, "Invalid 'revision'"
    end
  end

  # ===========================================
  # Tests for version maps (unified convention)
  # ===========================================

  def test_valid_icon_version_map_with_string_values
    yaml = <<~YAML
      icon:
        default: modern-purple-flat
        "30": with-modern-vscode-icon
    YAML
    with_temp_config(yaml) do |path|
      result = load_config_from_path(path)
      assert_equal "modern-purple-flat", result[:config]["icon"]["default"]
      assert_equal "with-modern-vscode-icon", result[:config]["icon"]["30"]
    end
  end

  def test_valid_icon_version_map_with_external_values
    yaml = <<~YAML
      icon:
        default: modern-purple-flat
        "31":
          url: https://example.com/icon.icns
          sha256: abc123
    YAML
    with_temp_config(yaml) do |path|
      result = load_config_from_path(path)
      assert_equal "https://example.com/icon.icns", result[:config]["icon"]["31"]["url"]
    end
  end

  def test_valid_icon_version_map_without_default
    yaml = <<~YAML
      icon:
        "31": modern-purple-flat
    YAML
    with_temp_config(yaml) do |path|
      result = load_config_from_path(path)
      assert_equal "modern-purple-flat", result[:config]["icon"]["31"]
    end
  end

  def test_valid_icon_version_map_with_integer_keys
    yaml = <<~YAML
      icon:
        30: modern-purple-flat
    YAML
    with_temp_config(yaml) do |path|
      result = load_config_from_path(path)
      assert_equal "modern-purple-flat", result[:config]["icon"][30]
    end
  end

  def test_invalid_icon_version_map_bad_key
    yaml = <<~YAML
      icon:
        stable: modern-purple-flat
    YAML
    with_temp_config(yaml) do |path|
      error = assert_raises(BuildConfig::ConfigurationError) do
        load_config_from_path(path)
      end
      assert_includes error.message, "Invalid 'icon'"
      assert_includes error.message, "stable"
      assert_includes error.message, "default"
    end
  end

  def test_invalid_icon_version_map_nested_map
    yaml = <<~YAML
      icon:
        "30":
          default: modern-purple-flat
    YAML
    with_temp_config(yaml) do |path|
      error = assert_raises(BuildConfig::ConfigurationError) do
        load_config_from_path(path)
      end
      assert_includes error.message, "Invalid 'icon"
    end
  end

  def test_invalid_icon_version_map_spec_missing_sha256
    yaml = <<~YAML
      icon:
        "30":
          url: https://example.com/icon.icns
    YAML
    with_temp_config(yaml) do |path|
      error = assert_raises(BuildConfig::ConfigurationError) do
        load_config_from_path(path)
      end
      assert_includes error.message, "sha256"
    end
  end

  def test_invalid_icon_version_map_non_string_value
    yaml = <<~YAML
      icon:
        "30": 5
    YAML
    with_temp_config(yaml) do |path|
      error = assert_raises(BuildConfig::ConfigurationError) do
        load_config_from_path(path)
      end
      assert_includes error.message, "Invalid 'icon"
    end
  end

  def test_valid_patch_version_map
    yaml = <<~YAML
      patches:
        - my-patch:
            "31":
              url: ./my-patch.patch
              sha256: abc123
    YAML
    with_temp_config(yaml) do |path|
      result = load_config_from_path(path)
      spec = result[:config]["patches"].first["my-patch"]
      assert_equal "./my-patch.patch", spec["31"]["url"]
    end
  end

  def test_valid_patch_version_map_with_default
    yaml = <<~YAML
      patches:
        - my-patch:
            default:
              url: ./my-patch.patch
              sha256: abc123
            "31":
              url: ./my-patch-31.patch
              sha256: def456
    YAML
    with_temp_config(yaml) do |path|
      result = load_config_from_path(path)
      spec = result[:config]["patches"].first["my-patch"]
      assert_equal "./my-patch-31.patch", spec["31"]["url"]
      assert_equal "./my-patch.patch", spec["default"]["url"]
    end
  end

  def test_valid_patch_external_spec_still_works
    yaml = <<~YAML
      patches:
        - registry-patch
        - my-patch:
            url: https://example.com/my.patch
            sha256: abc123
    YAML
    with_temp_config(yaml) do |path|
      result = load_config_from_path(path)
      assert_equal "registry-patch", result[:config]["patches"].first
    end
  end

  def test_invalid_patch_version_map_bad_key
    yaml = <<~YAML
      patches:
        - my-patch:
            stable:
              url: ./my.patch
              sha256: abc123
    YAML
    with_temp_config(yaml) do |path|
      error = assert_raises(BuildConfig::ConfigurationError) do
        load_config_from_path(path)
      end
      assert_includes error.message, "my-patch"
      assert_includes error.message, "stable"
    end
  end

  def test_invalid_patch_version_map_value_not_spec
    yaml = <<~YAML
      patches:
        - my-patch:
            "31": just-a-string
    YAML
    with_temp_config(yaml) do |path|
      error = assert_raises(BuildConfig::ConfigurationError) do
        load_config_from_path(path)
      end
      assert_includes error.message, "my-patch"
    end
  end

  def test_invalid_patch_spec_missing_sha256
    yaml = <<~YAML
      patches:
        - my-patch:
            url: https://example.com/my.patch
    YAML
    with_temp_config(yaml) do |path|
      error = assert_raises(BuildConfig::ConfigurationError) do
        load_config_from_path(path)
      end
      assert_includes error.message, "my-patch"
      assert_includes error.message, "sha256"
    end
  end

  def test_invalid_patch_entry_number
    yaml = <<~YAML
      patches:
        - 42
    YAML
    with_temp_config(yaml) do |path|
      error = assert_raises(BuildConfig::ConfigurationError) do
        load_config_from_path(path)
      end
      assert_includes error.message, "Invalid 'patches"
    end
  end

  def test_valid_revision_map_with_default
    yaml = <<~YAML
      revision:
        default: abc123
        "31": def456
    YAML
    with_temp_config(yaml) do |path|
      result = load_config_from_path(path)
      assert_equal "abc123", result[:config]["revision"]["default"]
      assert_equal "def456", result[:config]["revision"]["31"]
    end
  end

  def test_invalid_revision_map_bad_key
    yaml = <<~YAML
      revision:
        stable: abc123
    YAML
    with_temp_config(yaml) do |path|
      error = assert_raises(BuildConfig::ConfigurationError) do
        load_config_from_path(path)
      end
      assert_includes error.message, "Invalid 'revision'"
      assert_includes error.message, "stable"
    end
  end

  # ===========================================
  # Tests for resolve_versioned
  # ===========================================

  def test_resolve_versioned_passes_through_string
    assert_equal "abc", BuildConfig.resolve_versioned("abc", "30")
  end

  def test_resolve_versioned_passes_through_nil
    assert_nil BuildConfig.resolve_versioned(nil, "30")
  end

  def test_resolve_versioned_passes_through_external_spec
    spec = { "url" => "https://example.com/x", "sha256" => "abc" }
    assert_equal spec, BuildConfig.resolve_versioned(spec, "30")
  end

  def test_resolve_versioned_exact_match_wins_over_default
    map = { "default" => "a", "30" => "b" }
    assert_equal "b", BuildConfig.resolve_versioned(map, "30")
  end

  def test_resolve_versioned_falls_back_to_default
    map = { "default" => "a", "30" => "b" }
    assert_equal "a", BuildConfig.resolve_versioned(map, "31")
  end

  def test_resolve_versioned_returns_nil_without_match_or_default
    map = { "30" => "b" }
    assert_nil BuildConfig.resolve_versioned(map, "31")
  end

  def test_resolve_versioned_matches_integer_keys
    map = { 30 => "b" }
    assert_equal "b", BuildConfig.resolve_versioned(map, "30")
  end

  def test_resolve_versioned_accepts_integer_version
    map = { "30" => "b" }
    assert_equal "b", BuildConfig.resolve_versioned(map, 30)
  end

  def test_resolve_versioned_nil_version_uses_default
    map = { "default" => "a", "30" => "b" }
    assert_equal "a", BuildConfig.resolve_versioned(map, nil)
  end

  def test_resolve_versioned_empty_hash_resolves_to_nil
    assert_nil BuildConfig.resolve_versioned({}, "30")
  end

  def test_invalid_icon_empty_hash_still_rejected
    with_temp_config("icon: {}") do |path|
      error = assert_raises(BuildConfig::ConfigurationError) do
        load_config_from_path(path)
      end
      assert_includes error.message, "sha256"
    end
  end

  # ===========================================
  # Tests for versioned resolve_icon
  # ===========================================

  def test_resolve_icon_versioned_external_spec
    config = {
      "icon" => {
        "31" => { "url" => "https://example.com/icon.icns", "sha256" => "abc123" },
      },
    }
    icon = BuildConfig.resolve_icon(config, version: "31")
    assert_equal "external", icon[:type]
    assert_equal "https://example.com/icon.icns", icon[:url]
  end

  def test_resolve_icon_versioned_no_match_returns_nil
    config = {
      "icon" => {
        "31" => { "url" => "https://example.com/icon.icns", "sha256" => "abc123" },
      },
    }
    assert_nil BuildConfig.resolve_icon(config, version: "30")
  end

  def test_resolve_icon_versioned_default_fallback
    config = {
      "icon" => {
        "default" => { "url" => "https://example.com/d.icns", "sha256" => "d" },
        "31" => { "url" => "https://example.com/31.icns", "sha256" => "e" },
      },
    }
    icon = BuildConfig.resolve_icon(config, version: "30")
    assert_equal "https://example.com/d.icns", icon[:url]
  end

  def test_resolve_icon_without_version_uses_default
    config = {
      "icon" => {
        "default" => { "url" => "https://example.com/d.icns", "sha256" => "d" },
      },
    }
    icon = BuildConfig.resolve_icon(config)
    assert_equal "https://example.com/d.icns", icon[:url]
  end

  def test_resolve_icon_plain_external_still_works
    config = {
      "icon" => { "url" => "https://example.com/icon.icns", "sha256" => "abc123" },
    }
    icon = BuildConfig.resolve_icon(config, version: "30")
    assert_equal "external", icon[:type]
  end

  # ===========================================
  # Tests for context warnings
  # ===========================================

  def test_cask_context_warns_about_patches
    config = { "patches" => ["test"] }
    warnings = BuildConfig.context_warnings(config, :cask)
    assert_equal 1, warnings.length
    assert_includes warnings.first, "patches"
    assert_includes warnings.first, "ignored"
  end

  def test_cask_context_warns_about_revision
    config = { "revision" => "abc123" }
    warnings = BuildConfig.context_warnings(config, :cask)
    assert_equal 1, warnings.length
    assert_includes warnings.first, "revision"
    assert_includes warnings.first, "ignored"
  end

  def test_formula_context_no_warning_for_inject_path
    # inject_path applies to both formula and cask, so no warning
    config = { "inject_path" => true }
    warnings = BuildConfig.context_warnings(config, :formula)
    assert_empty warnings
  end

  def test_cask_context_no_warning_for_icon
    config = { "icon" => "test" }
    warnings = BuildConfig.context_warnings(config, :cask)
    assert_empty warnings
  end

  def test_formula_context_no_warning_for_patches
    config = { "patches" => ["test"] }
    warnings = BuildConfig.context_warnings(config, :formula)
    assert_empty warnings
  end

  # ===========================================
  # Tests for print_config
  # ===========================================

  def test_print_config_formats_string_value
    output = []
    config = { "icon" => "modern-icon" }
    BuildConfig.print_config(config, "/test/path", output: ->(msg) { output << msg })
    assert_includes output.join("\n"), "icon: modern-icon"
  end

  def test_print_config_formats_array_value
    output = []
    config = { "patches" => ["a", "b"] }
    BuildConfig.print_config(config, "/test/path", output: ->(msg) { output << msg })
    assert_includes output.join("\n"), "patches: a, b"
  end

  def test_print_config_shows_cask_warnings
    output = []
    config = { "patches" => ["test"] }
    BuildConfig.print_config(config, "/test/path", context: :cask, output: ->(msg) { output << msg })
    combined = output.join("\n")
    assert_includes combined, "⚠"
    assert_includes combined, "patches"
  end

  def test_print_config_empty_config_produces_no_output
    output = []
    BuildConfig.print_config({}, "/test/path", output: ->(msg) { output << msg })
    assert_empty output
  end

  # ===========================================
  # Tests for native_comp_driver_options_el (issue #964)
  # ===========================================

  def test_driver_options_el_interpolates_prefix
    el = BuildConfig.native_comp_driver_options_el("/opt/homebrew")
    assert_includes el, "/opt/homebrew/opt/gcc/bin/gcc-[0-9]*"
    assert_includes el, "/opt/homebrew/lib/gcc/current"
    assert_includes el, "/opt/homebrew/opt/libgccjit/lib/gcc/current"

    el_intel = BuildConfig.native_comp_driver_options_el("/usr/local")
    assert_includes el_intel, "/usr/local/opt/gcc/bin/gcc-[0-9]*"
    refute_includes el_intel, "/opt/homebrew"
  end

  def test_driver_options_el_guards_on_native_comp
    el = BuildConfig.native_comp_driver_options_el("/opt/homebrew")
    assert_includes el, "native-comp-available-p"
    assert_includes el, "native-comp-driver-options"
    assert_includes el, "-print-file-name=libemutls_w.a"
  end

  def test_driver_options_el_has_balanced_parens
    el = BuildConfig.native_comp_driver_options_el("/opt/homebrew")
    # Strip comment lines, then count parens
    code = el.lines.reject { |l| l.strip.start_with?(";;") }.join
    assert_equal code.count("("), code.count(")")
  end

  private

  # Helper to load config from a specific path using the environment variable
  def load_config_from_path(path)
    old_env = ENV["HOMEBREW_EMACS_PLUS_BUILD_CONFIG"]
    ENV["HOMEBREW_EMACS_PLUS_BUILD_CONFIG"] = path
    BuildConfig.load_config
  ensure
    if old_env
      ENV["HOMEBREW_EMACS_PLUS_BUILD_CONFIG"] = old_env
    else
      ENV.delete("HOMEBREW_EMACS_PLUS_BUILD_CONFIG")
    end
  end

  def with_temp_config(content)
    Tempfile.create(['build', '.yml']) do |f|
      f.write(content)
      f.flush
      yield f.path
    end
  end
end
