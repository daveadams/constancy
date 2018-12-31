# This software is public domain. No rights are reserved. See LICENSE for more information.

class Constancy
  class CLI
    class ConfigCommand
      class << self
        def run
          Constancy::CLI.configure(call_external_apis: false)

          puts " Config file: #{Constancy.config.config_file}"
          puts "  Consul URL: #{Constancy.config.consul.url}"
          puts "     Verbose: #{Constancy.config.verbose?.to_s.bold}"
          if Constancy.config.consul_token_source == "env"
            puts
            puts "Token Source: CONSUL_TOKEN or CONSUL_HTTP_TOKEN environment variable"

          elsif Constancy.config.consul_token_source == "vault"
            puts
            puts "Token Source: Vault"
            puts "   Vault URL: #{Constancy.config.vault_config.url}"
            puts "  Token Path: #{Constancy.config.vault_config.consul_token_path}"
            puts " Token Field: #{Constancy.config.vault_config.consul_token_field}"
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
            puts " Datacenter: #{target.datacenter}"
            puts "  Local type: #{target.type == :dir ? 'Directory' : 'Single file'}"
            puts "   #{target.type == :dir ? " Dir" : "File"} path: #{target.path}"
            puts "      Prefix: #{target.prefix}"
            puts "   Autochomp? #{target.chomp?}"
            puts "      Delete? #{target.delete?}"
            if not target.exclude.empty?
              puts "  Exclusions:"
              target.exclude.each do |exclusion|
                puts "    - #{exclusion}"
              end
            end
            puts
          end
        end
      end
    end
  end
end
