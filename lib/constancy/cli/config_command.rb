# This software is public domain. No rights are reserved. See LICENSE for more information.

class Constancy
  class CLI
    class ConfigCommand
      class << self
        def run
          Constancy::CLI.configure

          puts "Config file: #{Constancy.config.config_file}"
          puts " Consul URL: #{Constancy.config.consul.url}"
          puts "    Verbose: #{Constancy.config.verbose?.to_s.bold}"
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
            puts "   File path: #{target.path}"
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
