# This software is public domain. No rights are reserved. See LICENSE for more information.

class Constancy
  class CLI
    class TargetsCommand
      class << self
        def run
          Constancy::CLI.configure(call_external_apis: false)

          Constancy.config.sync_targets.each do |target|
            if target.name
              puts target.name
            else
              puts "[unnamed target] #{target.datacenter}:#{target.prefix}"
            end
          end
        end
      end
    end
  end
end
