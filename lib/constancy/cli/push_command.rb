# This software is public domain. No rights are reserved. See LICENSE for more information.

class Constancy
  class CLI
    class PushCommand
      class << self
        def run
          Constancy::CLI.configure
          STDOUT.sync = true

          Constancy.config.sync_targets.each do |target|
            target.print_report

            if not target.any_changes?
              puts
              puts "Everything is in sync. No changes need to be made to this sync target."
              next
            end

            puts
            puts "Do you want to push these changes?"
            print "  Enter '" + "yes".bold + "' to continue: "
            answer = gets.chomp

            if answer.downcase != "yes"
              puts
              puts "Push cancelled. No changes will be made to this sync target."
              next
            end

            puts
            target.items_to_change.each do |item|
              case item[:op]
              when :create
                print "CREATE".bold.green + " " + item[:consul_key]
                resp = target.consul.put(item[:consul_key], item[:local_content], dc: target.datacenter)
                if resp.success?
                  puts "   OK".bold
                else
                  puts "   ERROR".bold.red
                end

              when :update
                print "UPDATE".bold.blue + " " + item[:consul_key]
                resp = target.consul.put(item[:consul_key], item[:local_content], dc: target.datacenter)
                if resp.success?
                  puts "   OK".bold
                else
                  puts "   ERROR".bold.red
                end

              when :delete
                print "DELETE".bold.red + " " + item[:consul_key]
                resp = target.consul.delete(item[:consul_key], dc: target.datacenter)
                if resp.success?
                  puts "   OK".bold
                else
                  puts "   ERROR".bold.red
                end

              else
                if Constancy.config.verbose?
                  STDERR.puts "constancy: WARNING: unexpected operation '#{item[:op]}' for #{item[:consul_key]}"
                  next
                end

              end
            end
          end
        end
      end
    end
  end
end
