#!/usr/bin/env ruby
# frozen_string_literal: true

# Test suite for the Emacs Client.app AppleScript
#
# Run with: ruby tests/test_client_app_script.rb
#
# The script lives in five places: the formula build (Library/EmacsBase.rb),
# the cask postflight (Library/CaskEnv.rb) and the three cask build jobs in
# .github/workflows/build-app.yml. All of them must bring Emacs to the front
# the same way.
#
# `open -a Emacs` must not be used for that: it asks LaunchServices for an
# Emacs.app by name, and LaunchServices picks the one launched most recently,
# not the daemon emacsclient talks to. With another Emacs.app around (a copy
# in /Applications, another emacs-plus@N), it starts a second Emacs next to
# the daemon (discussion #1020). `tell application id` targets the running
# process instead.

require 'minitest/autorun'
require 'open3'
require 'tmpdir'

class TestClientAppScript < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  SOURCES = {
    "Library/EmacsBase.rb" => 1,
    "Library/CaskEnv.rb" => 1,
    ".github/workflows/build-app.yml" => 3
  }.freeze
  SCRIPT = /(^[ \t]*-- Emacs Client AppleScript Application\n.*?)^[ \t]*(?:EOS|APPLESCRIPT|APPLESCRIPT_EOF)$/m
  HANDLERS = {
    "open" => /^on open theDropped\n(.*?)^end open$/m,
    "run" => /^on run\n(.*?)^end run$/m,
    "open location" => /^on open location this_URL\n(.*?)^end open location$/m
  }.freeze
  ACTIVATE = /^on activateEmacs\(\)\n.*?^end activateEmacs$/m

  # [[source, script], ...] with each script dedented
  def scripts
    @scripts ||= SOURCES.keys.flat_map do |file|
      content = File.read(File.join(ROOT, file), encoding: "UTF-8")
      content.scan(SCRIPT).map { |(script)| [file, dedent(script)] }
    end
  end

  def dedent(text)
    indent = text.lines.reject { |l| l.strip.empty? }.map { |l| l[/\A[ \t]*/].size }.min
    text.lines.map { |l| l.strip.empty? ? "\n" : l[indent..] }.join
  end

  def activation_handler(script)
    script[ACTIVATE]
  end

  def code(script)
    script.lines.reject { |l| l.lstrip.start_with?("--") }.join
  end

  def test_finds_every_script
    SOURCES.each do |file, count|
      assert_equal count, scripts.count { |(source, _)| source == file }, file
    end
  end

  def test_scripts_do_not_use_open_a
    scripts.each do |(source, script)|
      refute_match(/open -a/, code(script), "#{source}: use activateEmacs() instead of open -a")
    end
  end

  def test_bundle_id_is_never_a_literal
    # osacompile resolves a literal `application id "..."` at compile time and
    # fails when the app is missing, e.g. on CI before Emacs.app is installed
    scripts.each do |(source, script)|
      refute_match(/application id "/, code(script), source)
    end
  end

  def test_every_handler_activates_emacs
    scripts.each do |(source, script)|
      HANDLERS.each do |name, pattern|
        body = script[pattern, 1]
        refute_nil body, "#{source}: no 'on #{name}' handler"
        assert_includes body, "my activateEmacs()", "#{source}: 'on #{name}' does not activate Emacs"
      end
    end
  end

  def test_activation_handler_is_the_same_everywhere
    handlers = scripts.map { |(_, script)| activation_handler(script) }
    refute_includes handlers, nil, "every script defines activateEmacs()"
    assert_equal 1, handlers.uniq.size, "activateEmacs() differs between copies"
  end

  def test_scripts_compile
    scripts.each_with_index do |(source, script), i|
      # Fill in what Ruby interpolation or the workflow's sed would
      rendered = script.gsub(/#\{[^}]*\}/, "/usr/bin/true").gsub("EMACSCLIENT_PATH", "/usr/bin/true")
      Dir.mktmpdir do |dir|
        file = File.join(dir, "client-#{i}.applescript")
        File.write(file, rendered)
        _, stderr, status = Open3.capture3("osacompile", "-o", File.join(dir, "Client.app"), file)
        assert status.success?, "#{source}: osacompile failed: #{stderr}"
      end
    end
  end

  def test_activation_handler_compiles_and_runs_without_emacs
    handler = activation_handler(scripts.first.last)
    refute_nil handler
    # A bundle id that matches no installed app, like on a CI runner
    script = "on run\n  my activateEmacs()\nend run\n\n" +
             handler.sub('"org.gnu.Emacs"', '"org.example.emacs-plus.missing"') + "\n"

    Dir.mktmpdir do |dir|
      source = File.join(dir, "activate.applescript")
      File.write(source, script)

      _, stderr, status = Open3.capture3("osacompile", "-o", File.join(dir, "Test.app"), source)
      assert status.success?, "osacompile failed: #{stderr}"

      _, stderr, status = Open3.capture3("osascript", source)
      assert status.success?, "activating a missing app must fail silently: #{stderr}"
    end
  end
end
