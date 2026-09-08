# frozen_string_literal: true

# CaskPostflightCLI - Command-line entry point for the cask postflight
#
# Homebrew's `postflight_steps` only accepts literal step calls, no Ruby,
# so the casks run scripts/cask-postflight (which execs this module) as a
# `run` step. It parses the arguments the cask passes, provides the
# `system_command` interface CaskPostflight expects from a cask context,
# and reports errors with a non-zero exit status so Homebrew aborts the
# install instead of leaving a half-configured bundle behind.
#
# Usage:
#   cask-postflight --emacs-app PATH --emacs-client-app PATH \
#                   --version MAJOR --homebrew-prefix PATH

require_relative 'CaskPostflight'

module CaskPostflightCLI
  class UsageError < StandardError; end

  OPTIONS = {
    '--emacs-app'        => :emacs_app,
    '--emacs-client-app' => :emacs_client_app,
    '--version'          => :version,
    '--homebrew-prefix'  => :homebrew_prefix,
  }.freeze

  USAGE = "Usage: cask-postflight #{OPTIONS.keys.map { |o| "#{o} VALUE" }.join(' ')}"

  # Stand-in for the cask block's system_command. Failures are reported
  # but do not abort: quarantine removal and re-signing were best effort
  # in the legacy postflight too, and a missing xattr must not block the
  # rest of the setup.
  class ShellContext
    def system_command(cmd, args: [], sudo: false)
      raise ArgumentError, "sudo is not available in the cask postflight" if sudo

      return true if system(cmd, *args)

      warn "Warning: #{([cmd] + args).join(' ')} failed with status #{$?.exitstatus}"
      false
    end
  end

  class << self
    def parse(argv)
      options = {}
      args = argv.dup
      until args.empty?
        flag = args.shift
        key = OPTIONS[flag]
        raise UsageError, "unknown option #{flag}" unless key
        raise UsageError, "#{flag} needs a value" if args.empty?

        options[key] = args.shift
      end

      missing = OPTIONS.values - options.keys
      raise UsageError, "missing #{OPTIONS.key(missing.first)}" unless missing.empty?

      options
    end

    # Returns the process exit status
    def run(argv)
      options = parse(argv)
      # CaskEnv reads the prefix from the environment outside Homebrew
      ENV['HOMEBREW_PREFIX'] = options[:homebrew_prefix]
      CaskPostflight.run(ShellContext.new,
                         emacs_app:        options[:emacs_app],
                         emacs_client_app: options[:emacs_client_app],
                         version:          options[:version])
      0
    rescue UsageError => e
      warn "Error: #{e.message}"
      warn USAGE
      2
    rescue BuildConfig::ConfigurationError => e
      warn "Error: #{e.message}"
      1
    end
  end
end
