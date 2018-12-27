# This software is public domain. No rights are reserved. See LICENSE for more information.

class Constancy
  class CLI
    class PullCommand
      class << self
        def run
          Constancy::CLI.configure
          STDOUT.sync = true

          Constancy.config.sync_targets.each do |target|
            diff = target.diff(:pull)

            diff.print_report

            if not diff.any_changes?
              puts
              puts "Everything is in sync. No changes need to be made to this sync target."
              next
            end

            puts
            puts "Do you want to pull these changes?"
            print "  Enter '" + "yes".bold + "' to continue: "
            answer = gets.chomp

            if answer.downcase != "yes"
              puts
              puts "Pull cancelled. No changes will be made to this sync target."
              next
            end

            puts
            diff.items_to_change.each do |item|
              case item.op
              when :create
                print "CREATE".bold.green + " " + item.display_filename
                begin
                  FileUtils.mkdir_p(File.dirname(item.filename))
                  # attempt to write atomically-ish
                  tmpfile = item.filename + ".constancy-tmp"
                  File.open(tmpfile, "w") do |f|
                    f.write(item.remote_content)
                  end
                  FileUtils.move(tmpfile, item.filename)
                  puts "   OK".bold
                rescue => e
                  puts "   ERROR".bold.red
                  puts "  #{e}"
                end

              when :update
                print "UPDATE".bold.blue + " " + item.display_filename
                begin
                  # attempt to write atomically-ish
                  tmpfile = item.filename + ".constancy-tmp"
                  File.open(tmpfile, "w") do |f|
                    f.write(item.remote_content)
                  end
                  FileUtils.move(tmpfile, item.filename)
                  puts "   OK".bold
                rescue => e
                  puts "   ERROR".bold.red
                  puts "  #{e}"
                end

              when :delete
                print "DELETE".bold.red + " " + item.display_filename
                begin
                  File.unlink(item.filename)
                  puts "   OK".bold
                rescue => e
                  puts "   ERROR".bold.red
                  puts "  #{e}"
                end

              else
                if Constancy.config.verbose?
                  STDERR.puts "constancy: WARNING: unexpected operation '#{item.op}' for #{item.display_filename}"
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
