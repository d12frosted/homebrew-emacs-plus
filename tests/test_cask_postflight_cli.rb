#!/usr/bin/env ruby
# frozen_string_literal: true

# Test suite for CaskPostflightCLI, the entry point the casks run from
# postflight_steps (through scripts/cask-postflight)
#
# Run with: ruby tests/test_cask_postflight_cli.rb

require 'minitest/autorun'
require 'minitest/mock'
require 'tmpdir'
require 'fileutils'
require 'stringio'

# Mock Hardware::CPU for testing without Homebrew (CaskEnv depends on it)
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

require_relative '../Library/CaskPostflightCLI'

class TestCaskPostflightCLI < Minitest::Test
  ARGS = [
    '--emacs-app', '/Applications/Emacs.app',
    '--emacs-client-app', '/Applications/Emacs Client.app',
    '--version', '31',
    '--homebrew-prefix', '/opt/homebrew',
  ].freeze

  def setup
    Hardware::CPU.mock_arm = true
    @saved_prefix = ENV['HOMEBREW_PREFIX']
  end

  def teardown
    if @saved_prefix
      ENV['HOMEBREW_PREFIX'] = @saved_prefix
    else
      ENV.delete('HOMEBREW_PREFIX')
    end
  end

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
    options = CaskPostflightCLI.parse(ARGS)
    assert_equal '/Applications/Emacs.app', options[:emacs_app]
    assert_equal '/Applications/Emacs Client.app', options[:emacs_client_app]
    assert_equal '31', options[:version]
    assert_equal '/opt/homebrew', options[:homebrew_prefix]
  end

  def test_parse_rejects_missing_option
    error = assert_raises(CaskPostflightCLI::UsageError) do
      CaskPostflightCLI.parse(ARGS.reject.with_index { |_, i| [4, 5].include?(i) })
    end
    assert_includes error.message, '--version'
  end

  def test_parse_rejects_unknown_option
    error = assert_raises(CaskPostflightCLI::UsageError) do
      CaskPostflightCLI.parse(ARGS + ['--bogus', 'x'])
    end
    assert_includes error.message, '--bogus'
  end

  def test_parse_rejects_option_without_value
    assert_raises(CaskPostflightCLI::UsageError) do
      CaskPostflightCLI.parse(ARGS[0..-2])
    end
  end

  # ===========================================
  # ShellContext: the system_command the postflight expects from a cask
  # ===========================================

  def test_shell_context_runs_the_command
    Dir.mktmpdir do |dir|
      target = File.join(dir, 'touched')
      ctx = CaskPostflightCLI::ShellContext.new
      capture { ctx.system_command('/usr/bin/touch', args: [target], sudo: false) }
      assert File.exist?(target)
    end
  end

  def test_shell_context_warns_instead_of_raising_on_failure
    ctx = CaskPostflightCLI::ShellContext.new
    _out, err = capture { ctx.system_command('/usr/bin/false', args: [], sudo: false) }
    assert_includes err, '/usr/bin/false'
  end

  def test_shell_context_refuses_sudo
    ctx = CaskPostflightCLI::ShellContext.new
    assert_raises(ArgumentError) do
      ctx.system_command('/usr/bin/true', args: [], sudo: true)
    end
  end

  # ===========================================
  # run: wiring into CaskPostflight
  # ===========================================

  def test_run_calls_cask_postflight_with_parsed_options
    received = nil
    CaskPostflight.stub(:run, lambda { |ctx, **kwargs|
      received = [ctx, kwargs]
      nil
    }) do
      status = nil
      capture { status = CaskPostflightCLI.run(ARGS) }
      assert_equal 0, status
    end
    ctx, kwargs = received
    assert_kind_of CaskPostflightCLI::ShellContext, ctx
    assert_equal({ emacs_app: '/Applications/Emacs.app',
                   emacs_client_app: '/Applications/Emacs Client.app',
                   version: '31' }, kwargs)
  end

  def test_run_exports_homebrew_prefix_for_cask_env
    CaskPostflight.stub(:run, ->(*) { nil }) do
      capture { CaskPostflightCLI.run(ARGS) }
    end
    assert_equal '/opt/homebrew', ENV['HOMEBREW_PREFIX']
  end

  def test_run_reports_usage_errors
    status = nil
    _out, err = capture { status = CaskPostflightCLI.run(['--emacs-app']) }
    assert_equal 2, status
    assert_includes err, 'Usage'
  end

  def test_run_reports_configuration_errors
    CaskPostflight.stub(:run, ->(*) { raise BuildConfig::ConfigurationError, 'bad icon' }) do
      status = nil
      _out, err = capture { status = CaskPostflightCLI.run(ARGS) }
      assert_equal 1, status
      assert_includes err, 'bad icon'
    end
  end
end
