# This software is public domain. No rights are reserved. See LICENSE for more information.

require 'constancy'
require 'diffy'
require 'constancy/cli/check_command'
require 'constancy/cli/push_command'
require 'constancy/cli/config_command'

class Constancy
  class CLI
    class << self
      attr_accessor :command, :cli_mode, :config_file, :extra_args, :targets

      def parse_args(args)
        self.print_usage if args.count < 1
        self.command = nil
        self.config_file = nil
        self.extra_args = []
        self.cli_mode = :command

        while arg = args.shift
          case arg
          when "--help"
            self.cli_mode = :help

          when "--config"
            self.config_file = args.shift

          when "--target"
            self.targets = (args.shift||'').split(",")

          when /^-/
            # additional option, maybe for the command
            self.extra_args << arg

          else
            if self.command.nil?
              # if command is not set, this is probably the command
              self.command = arg
            else
              # otherwise, pass it thru to the child command
              self.extra_args << arg
            end
          end
        end
      end

      def print_usage
        STDERR.puts <<USAGE
Usage:
  #{File.basename($0)} <command> [options]

Commands:
  check        Print a summary of changes to be made
  push         Push changes from filesystem to Consul
  config       Print a summary of the active configuration

General options:
  --help           Print help for the given command
  --config <file>  Use the specified config file
  --target <tgt>   Only apply to the specified target name or names (comma-separated)

USAGE
        exit 1
      end

      def configure(call_external_apis: true)
        return if Constancy.configured?

        begin
          Constancy.configure(path: self.config_file, targets: self.targets, call_external_apis: call_external_apis)

        rescue Constancy::ConfigFileNotFound
          if self.config_file.nil?
            STDERR.puts "constancy: ERROR: No configuration file found"
          else
            STDERR.puts "constancy: ERROR: Configuration file '#{self.config_file}' was not found"
          end
          exit 1

        rescue Constancy::ConfigFileInvalid => e
          if self.config_file.nil?
            STDERR.puts "constancy: ERROR: Configuration file is invalid:"
          else
            STDERR.puts "constancy: ERROR: Configuration file '#{self.config_file}' is invalid:"
          end
          STDERR.puts "  #{e}"
          exit 1

        rescue Constancy::ConsulTokenRequired => e
          STDERR.puts "constancy: ERROR: No Consul token could be found: #{e}"
          exit 1

        rescue Constancy::VaultConfigInvalid => e
          STDERR.puts "constancy: ERROR: Vault configuration invalid: #{e}"
          exit 1

        end

        if Constancy.config.sync_targets.count < 1
          if self.targets.nil?
            STDERR.puts "constancy: WARNING: No sync targets are defined"
          else
            STDERR.puts "constancy: WARNING: No sync targets were found that matched the specified list"
          end
        end
      end

      def run
        self.parse_args(ARGV)

        case self.cli_mode
        when :help
          # TODO: per-command help
          self.print_usage

        when :command
          case self.command
          when 'check'      then Constancy::CLI::CheckCommand.run
          when 'push'       then Constancy::CLI::PushCommand.run
          when 'config'     then Constancy::CLI::ConfigCommand.run
          when nil          then self.print_usage

          else
            STDERR.puts "constancy: ERROR: unknown command '#{self.command}'"
            STDERR.puts
            self.print_usage
          end

        else
          STDERR.puts "constancy: ERROR: unknown CLI mode '#{self.cli_mode}'"
          exit 1

        end
      end
    end
  end
end
