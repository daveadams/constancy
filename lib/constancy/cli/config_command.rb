# This software is public domain. No rights are reserved. See LICENSE for more information.

class Constancy
  class CLI
    class ConfigCommand
      class << self
        def run
          Constancy::CLI.configure(call_external_apis: false)

          puts " Config file: #{Constancy.config.config_file}"
          puts "  Consul URL: #{Constancy.config.consul_url}"
          puts "     Verbose: #{Constancy.config.verbose?.to_s.bold}"
          puts
          puts " Defined Consul Token Sources:"
          default_src_name = Constancy.config.default_consul_token_source.name
          srcs = Constancy.config.consul_token_sources
          ( %w( none env ) + ( srcs.keys.sort - %w( none env ) ) ).each do |name|
            puts
            puts "   #{name}:#{ default_src_name == name ? " (DEFAULT)".bold : ""}"
            case name
            when "none"
              puts "     uses CONSUL_HTTP_TOKEN or CONSUL_TOKEN env var if available"
            when "env"
              puts "     requires CONSUL_HTTP_TOKEN or CONSUL_TOKEN env var"
            when /^vault/
              puts "     address: #{srcs[name].vault_addr}"
              puts "        path: #{srcs[name].consul_token_path}"
              puts "       field: #{srcs[name].consul_token_field}"
            end
          end
          puts
          puts "Sync target defaults:"
          puts "  Chomp trailing newlines from local files: #{Constancy.config.chomp?.to_s.bold}"
          puts "  Delete remote keys with no local file: #{Constancy.config.delete?.to_s.bold}"
          puts
          puts "Sync targets:"

          Constancy.config.sync_targets.each do |target|
            if target.name
              puts "* #{target.name.bold}"
              print ' '
            else
              print '*'
            end
            puts "   Datacenter: #{target.datacenter}"
            puts "    Local type: #{target.type == :dir ? 'Directory' : 'Single file'}"
            puts "     #{target.type == :dir ? " Dir" : "File"} path: #{target.path}"
            puts "        Prefix: #{target.prefix}"
            puts "  Token Source: #{target.token_source.name}"
            puts "     Autochomp? #{target.chomp?}"
            puts "        Delete? #{target.delete?}"
            if not target.exclude.empty?
              puts "    Exclusions:"
              target.exclude.each do |exclusion|
                puts "      - #{exclusion}"
              end
            end
            puts
          end
        end
      end
    end
  end
end
