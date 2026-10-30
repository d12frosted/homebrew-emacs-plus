#!/usr/bin/env ruby
# frozen_string_literal: true

# Test suite for how the casks and formulas reach the tap scripts and the
# ruby that runs them
#
# Run with: ruby tests/test_postflight_launch.rb
#
# Taps live in HOMEBREW_REPOSITORY/Library/Taps, which is HOMEBREW_PREFIX
# only on the default layout. When bin/brew is a symlink into a separate
# repository (/opt/homebrew/Homebrew, say), the two differ (#1039), so the
# tests build that split layout in a temporary directory.

require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require 'open3'

class TestPostflightLaunch < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  CASKS = %w[emacs-plus-app emacs-plus-app@next emacs-plus-app@master].freeze
  SCRIPTS = %w[cask-postflight formula-postinstall].freeze
  TAP = "Library/Taps/d12frosted/homebrew-emacs-plus"
  PORTABLE_RUBY = "Library/Homebrew/vendor/portable-ruby/current/bin/ruby"
  ARGS = ["--emacs-app", "/Users/me/Applications/Emacs.app", "--version", "31"].freeze

  def setup
    @dir = Dir.mktmpdir
    @prefix = File.join(@dir, "prefix")
    @repository = File.join(@prefix, "Homebrew")
    FileUtils.mkdir_p(@prefix)
  end

  def teardown
    FileUtils.rm_rf(@dir)
  end

  # Writes an executable that prints its name and arguments, one per line
  def stub(path, name)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, "#!/bin/bash\nprintf '%s\\n' #{name} \"$@\"\n")
    File.chmod(0o755, path)
  end

  # Runs with only the given HOMEBREW_* variables, so the developer's own
  # Homebrew environment does not leak in
  def run_clean(env, *command)
    out, err, status = Open3.capture3({ "PATH" => "/usr/bin:/bin" }.merge(env), *command, unsetenv_others: true)
    assert status.success?, "#{command.first} failed: #{err}"
    out.lines(chomp: true)
  end

  # The program the cask's postflight `run` step hands to bash, with the
  # template tokens expanded the way Homebrew expands them
  def cask_program(name)
    source = File.read("#{ROOT}/Casks/#{name}.rb")
    literals = source[/run "\/bin\/bash",\s*args:\s*\["-c",\s*((?:'[^']*'\s*\\?\s*)+),/, 1]
    refute_nil literals, "#{name} runs cask-postflight through bash"
    literals.scan(/'([^']*)'/).join.gsub("{{HOMEBREW_PREFIX}}", @prefix)
  end

  def run_cask_step(name, env)
    run_clean(env, "/bin/bash", "-c", cask_program(name), "cask-postflight", *ARGS)
  end

  def test_casks_run_the_script_from_the_repository
    stub(File.join(@repository, TAP, "scripts/cask-postflight"), "repository")
    CASKS.each do |name|
      lines = run_cask_step(name, "HOMEBREW_PREFIX" => @prefix, "HOMEBREW_REPOSITORY" => @repository)
      assert_equal ["repository", *ARGS], lines, name
    end
  end

  def test_casks_fall_back_to_the_prefix
    stub(File.join(@prefix, TAP, "scripts/cask-postflight"), "prefix")
    CASKS.each do |name|
      lines = run_cask_step(name, "HOMEBREW_PREFIX" => @prefix)
      assert_equal ["prefix", *ARGS], lines, name
    end
  end

  # Copies a script into a tap inside the split layout and runs it, so the
  # path it derives from its own location is the real one
  def run_script(script, env)
    path = File.join(@repository, TAP, "scripts", script)
    FileUtils.mkdir_p(File.dirname(path))
    FileUtils.cp("#{ROOT}/scripts/#{script}", path)
    run_clean({ "HOMEBREW_PREFIX" => @prefix }.merge(env), path, *ARGS)
  end

  def test_scripts_prefer_homebrew_ruby_path
    ruby = File.join(@dir, "ruby-path/ruby")
    stub(ruby, "ruby-path")
    stub(File.join(@repository, PORTABLE_RUBY), "portable")
    SCRIPTS.each do |script|
      lines = run_script(script, "HOMEBREW_RUBY_PATH" => ruby, "HOMEBREW_REPOSITORY" => @repository)
      assert_equal "ruby-path", lines.first, script
    end
  end

  def test_scripts_find_portable_ruby_in_the_repository
    stub(File.join(@repository, PORTABLE_RUBY), "portable")
    SCRIPTS.each do |script|
      lines = run_script(script, "HOMEBREW_REPOSITORY" => @repository)
      assert_equal "portable", lines.first, script
    end
  end

  def test_scripts_find_portable_ruby_next_to_the_tap
    stub(File.join(@repository, PORTABLE_RUBY), "portable")
    SCRIPTS.each do |script|
      lines = run_script(script, {})
      assert_equal "portable", lines.first, script
    end
  end

  def test_scripts_pass_arguments_through
    stub(File.join(@repository, PORTABLE_RUBY), "portable")
    SCRIPTS.each do |script|
      lines = run_script(script, "HOMEBREW_REPOSITORY" => @repository)
      assert_equal ARGS, lines.last(ARGS.length), script
    end
  end
end
