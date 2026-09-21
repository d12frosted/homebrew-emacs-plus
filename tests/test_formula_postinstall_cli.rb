#!/usr/bin/env ruby
# frozen_string_literal: true

# Test suite for FormulaPostinstallCLI, the entry point the formulas run
# from post_install_steps (through scripts/formula-postinstall)
#
# Run with: ruby tests/test_formula_postinstall_cli.rb

require 'minitest/autorun'
require 'minitest/mock'
require 'tmpdir'
require 'stringio'

require_relative '../Library/FormulaPostinstallCLI'

class TestFormulaPostinstallCLI < Minitest::Test
  ARGS = [
    '--prefix', '/opt/homebrew/Cellar/emacs-plus@31/31.1',
    '--opt-prefix', '/opt/homebrew/opt/emacs-plus@31',
    '--version', '31',
    '--install-info',
    '--apply-icon',
    '--link-native-lisp',
  ].freeze

  def capture
    out = StringIO.new
    err = StringIO.new
    orig_out, orig_err = $stdout, $stderr
    $stdout, $stderr = out, err
    yield
    [out.string, err.string]
  ensure
    $stdout, $stderr = orig_out, orig_err
  end

  # ===========================================
  # Argument parsing
  # ===========================================

  def test_parse_reads_all_options
    options = FormulaPostinstallCLI.parse(ARGS)
    assert_equal '/opt/homebrew/Cellar/emacs-plus@31/31.1', options[:prefix]
    assert_equal '/opt/homebrew/opt/emacs-plus@31', options[:opt_prefix]
    assert_equal '31', options[:version]
    assert options[:install_info]
    assert options[:apply_icon]
    assert options[:link_native_lisp]
  end

  def test_parse_defaults_flags_to_false
    options = FormulaPostinstallCLI.parse(['--prefix', '/x'])
    assert_equal '/x', options[:prefix]
    refute options[:install_info]
    refute options[:apply_icon]
    refute options[:link_native_lisp]
  end

  def test_parse_rejects_missing_prefix
    error = assert_raises(FormulaPostinstallCLI::UsageError) do
      FormulaPostinstallCLI.parse(['--version', '31'])
    end
    assert_includes error.message, '--prefix'
  end

  def test_parse_rejects_apply_icon_without_version
    error = assert_raises(FormulaPostinstallCLI::UsageError) do
      FormulaPostinstallCLI.parse(['--prefix', '/x', '--apply-icon'])
    end
    assert_includes error.message, '--version'
  end

  def test_parse_rejects_link_native_lisp_without_opt_prefix
    error = assert_raises(FormulaPostinstallCLI::UsageError) do
      FormulaPostinstallCLI.parse(['--prefix', '/x', '--link-native-lisp'])
    end
    assert_includes error.message, '--opt-prefix'
  end

  def test_parse_rejects_unknown_option
    error = assert_raises(FormulaPostinstallCLI::UsageError) do
      FormulaPostinstallCLI.parse(ARGS + ['--bogus'])
    end
    assert_includes error.message, '--bogus'
  end

  def test_parse_rejects_option_without_value
    assert_raises(FormulaPostinstallCLI::UsageError) do
      FormulaPostinstallCLI.parse(['--prefix'])
    end
  end

  # ===========================================
  # ShellContext: failures abort like Formula#system did in post_install
  # ===========================================

  def test_shell_context_runs_the_command
    Dir.mktmpdir do |dir|
      target = File.join(dir, 'touched')
      ctx = FormulaPostinstallCLI::ShellContext.new
      ctx.system_command('/usr/bin/touch', args: [target])
      assert File.exist?(target)
    end
  end

  def test_shell_context_raises_on_failure
    ctx = FormulaPostinstallCLI::ShellContext.new
    error = assert_raises(FormulaPostinstall::CommandError) do
      ctx.system_command('/usr/bin/false', args: [])
    end
    assert_includes error.message, '/usr/bin/false'
  end

  def test_shell_context_raises_when_command_is_missing
    ctx = FormulaPostinstallCLI::ShellContext.new
    assert_raises(FormulaPostinstall::CommandError) do
      ctx.system_command('/nonexistent/command', args: [])
    end
  end

  # ===========================================
  # run: wiring into FormulaPostinstall
  # ===========================================

  def test_run_calls_formula_postinstall_with_parsed_options
    received = nil
    FormulaPostinstall.stub(:run, lambda { |ctx, **kwargs|
      received = [ctx, kwargs]
      nil
    }) do
      status = nil
      capture { status = FormulaPostinstallCLI.run(ARGS) }
      assert_equal 0, status
    end
    ctx, kwargs = received
    assert_kind_of FormulaPostinstallCLI::ShellContext, ctx
    assert_equal({ prefix: '/opt/homebrew/Cellar/emacs-plus@31/31.1',
                   opt_prefix: '/opt/homebrew/opt/emacs-plus@31',
                   version: '31',
                   install_info: true,
                   apply_icon: true,
                   link_native_lisp: true }, kwargs)
  end

  def test_run_reports_usage_errors_with_status_2
    status = nil
    _out, err = capture { status = FormulaPostinstallCLI.run(['--bogus']) }
    assert_equal 2, status
    assert_includes err, '--bogus'
    assert_includes err, 'Usage:'
  end

  def test_run_reports_configuration_errors_with_status_1
    FormulaPostinstall.stub(:run, ->(*) { raise BuildConfig::ConfigurationError, 'bad build.yml' }) do
      status = nil
      _out, err = capture { status = FormulaPostinstallCLI.run(ARGS) }
      assert_equal 1, status
      assert_includes err, 'bad build.yml'
    end
  end

  def test_run_reports_command_failures_with_status_1
    FormulaPostinstall.stub(:run, ->(*) { raise FormulaPostinstall::CommandError, 'codesign failed' }) do
      status = nil
      _out, err = capture { status = FormulaPostinstallCLI.run(ARGS) }
      assert_equal 1, status
      assert_includes err, 'codesign failed'
    end
  end
end
