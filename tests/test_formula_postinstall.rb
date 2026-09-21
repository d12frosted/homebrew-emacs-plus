#!/usr/bin/env ruby
# frozen_string_literal: true

# Test suite for FormulaPostinstall, the post-install logic the emacs-plus
# formulas run from post_install_steps
#
# Run with: ruby tests/test_formula_postinstall.rb

require 'minitest/autorun'
require 'minitest/mock'
require 'tmpdir'
require 'fileutils'
require 'stringio'

require_relative '../Library/FormulaPostinstall'

# Records system_command invocations instead of running them
class FakeContext
  Command = Struct.new(:cmd, :args, keyword_init: true)

  attr_reader :commands

  def initialize
    @commands = []
  end

  def system_command(cmd, args: [])
    @commands << Command.new(cmd: cmd, args: args)
  end
end

class TestFormulaPostinstall < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
    @prefix = File.join(@tmpdir, 'Cellar/emacs-plus@31/31.1')
    @opt_prefix = File.join(@tmpdir, 'opt/emacs-plus@31')
    FileUtils.mkdir_p(@prefix)
    FileUtils.mkdir_p(File.dirname(@opt_prefix))
    File.symlink(@prefix, @opt_prefix)
    @emacs_app = File.join(@prefix, 'Emacs.app')
    @client_app = File.join(@prefix, 'Emacs Client.app')
    @ctx = FakeContext.new
  end

  def teardown
    FileUtils.remove_entry(@tmpdir)
  end

  def make_apps(client: true)
    FileUtils.mkdir_p(File.join(@emacs_app, 'Contents/MacOS'))
    FileUtils.mkdir_p(File.join(@client_app, 'Contents')) if client
  end

  def make_info_files
    dir = File.join(@prefix, 'share/info/emacs')
    FileUtils.mkdir_p(dir)
    %w[emacs.info elisp.info.gz dir].each { |f| FileUtils.touch(File.join(dir, f)) }
    dir
  end

  def run_postinstall(**kwargs)
    icon_args = nil
    IconApplier.stub(:apply, lambda { |*args, **kw|
      icon_args = [args, kw]
      true
    }) do
      silence { FormulaPostinstall.run(@ctx, prefix: @prefix, **kwargs) }
    end
    { icon_args: icon_args }
  end

  def silence
    orig = $stdout
    $stdout = StringIO.new
    yield
  ensure
    $stdout = orig
  end

  def commands_for(cmd)
    @ctx.commands.select { |c| c.cmd == cmd }
  end

  # ===========================================
  # Info directory
  # ===========================================

  def test_registers_each_info_file_with_install_info
    dir = make_info_files
    run_postinstall(install_info: true)
    install_info = commands_for('install-info')
    assert_equal 2, install_info.size
    files = install_info.map { |c| c.args }
    assert_includes files, ["--info-dir=#{dir}", File.join(dir, 'elisp.info.gz')]
    assert_includes files, ["--info-dir=#{dir}", File.join(dir, 'emacs.info')]
  end

  def test_skips_install_info_unless_requested
    make_info_files
    run_postinstall
    assert_empty commands_for('install-info')
  end

  def test_skips_install_info_when_there_is_no_info_directory
    run_postinstall(install_info: true)
    assert_empty commands_for('install-info')
  end

  # ===========================================
  # native-lisp link (Emacs 28 and 29 with native-comp)
  # ===========================================

  def test_links_native_lisp_from_opt_prefix
    make_apps(client: false)
    native_lisp = File.join(@prefix, 'lib/emacs/31.1/native-lisp')
    FileUtils.mkdir_p(native_lisp)
    run_postinstall(link_native_lisp: true, opt_prefix: @opt_prefix)
    link = File.join(@emacs_app, 'Contents/native-lisp')
    assert File.symlink?(link)
    assert_equal File.join(@opt_prefix, 'lib/emacs/31.1/native-lisp'), File.readlink(link)
  end

  def test_skips_native_lisp_link_without_native_comp_build
    make_apps(client: false)
    FileUtils.mkdir_p(File.join(@prefix, 'lib/emacs/31.1'))
    run_postinstall(link_native_lisp: true, opt_prefix: @opt_prefix)
    refute File.exist?(File.join(@emacs_app, 'Contents/native-lisp'))
  end

  def test_skips_native_lisp_link_unless_requested
    make_apps(client: false)
    FileUtils.mkdir_p(File.join(@prefix, 'lib/emacs/31.1/native-lisp'))
    run_postinstall(opt_prefix: @opt_prefix)
    refute File.exist?(File.join(@emacs_app, 'Contents/native-lisp'))
  end

  # ===========================================
  # Icon application
  # ===========================================

  def test_passes_app_paths_and_version_to_icon_applier
    make_apps
    result = run_postinstall(apply_icon: true, version: '31')
    args, kwargs = result[:icon_args]
    assert_equal [@emacs_app, @client_app], args
    assert_equal({ version: '31' }, kwargs)
  end

  def test_skips_icon_unless_requested
    make_apps
    result = run_postinstall(version: '31')
    assert_nil result[:icon_args]
  end

  # ===========================================
  # Re-signing
  # ===========================================

  def test_resigns_both_apps
    make_apps
    run_postinstall
    codesign = commands_for('/usr/bin/codesign')
    assert_equal 2, codesign.size
    assert_equal ['--force', '--deep', '--sign', '-', @emacs_app], codesign[0].args
    assert_equal ['--force', '--deep', '--sign', '-', @client_app], codesign[1].args
  end

  def test_resigns_only_the_apps_that_exist
    make_apps(client: false)
    run_postinstall
    codesign = commands_for('/usr/bin/codesign')
    assert_equal 1, codesign.size
    assert_equal @emacs_app, codesign[0].args.last
  end

  def test_no_resign_without_app_bundles
    run_postinstall
    assert_empty commands_for('/usr/bin/codesign')
  end

  def test_resigns_after_the_other_steps
    make_apps
    make_info_files
    run_postinstall(install_info: true, apply_icon: true, version: '31')
    cmds = @ctx.commands.map(&:cmd)
    assert_operator cmds.rindex('install-info'), :<, cmds.index('/usr/bin/codesign')
  end
end
