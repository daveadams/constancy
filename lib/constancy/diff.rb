# This software is public domain. No rights are reserved. See LICENSE for more information.

class Constancy
  class Diff
    def initialize(target:, local:, remote:, mode:)
      @target = target
      @local = local
      @remote = remote
      @mode = mode

      @all_keys = (@local.keys + @remote.keys).sort.uniq

      @diff =
        @all_keys.collect do |key|
          excluded = false
          op = :noop
          if @remote.has_key?(key) and not @local.has_key?(key)
            case @mode
            when :push
              op = @target.delete? ? :delete : :ignore
            when :pull
              op = :create
            end
          elsif @local.has_key?(key) and not @remote.has_key?(key)
            case @mode
            when :push
              op = :create
            when :pull
              op = @target.delete? ? :delete : :ignore
            end
          else
            if @remote[key] == @local[key]
              op = :noop
            else
              op = :update
            end
          end

          consul_key = [@target.prefix, key].compact.join("/").squeeze("/")

          if @target.exclude.include?(key) or @target.exclude.include?(consul_key)
            op = :ignore
            excluded = true
          end

          filename =
            case @target.type
            when :dir then File.join(@target.base_path, key)
            when :file then @target.base_path
            end

          display_filename =
            case @target.type
            when :dir then File.join(@target.base_path, key).trim_path
            when :file then "#{@target.base_path.trim_path}#{':'.gray}#{key.cyan}"
            end

          OpenStruct.new(
            op: op,
            excluded: excluded,
            relative_path: key,
            filename: filename,
            display_filename: display_filename,
            consul_key: consul_key,
            local_content: @local[key],
            remote_content: @remote[key],
          )
        end
    end

    def items_to_delete
      @diff.select { |d| d.op == :delete }
    end

    def items_to_update
      @diff.select { |d| d.op == :update }
    end

    def items_to_create
      @diff.select { |d| d.op == :create }
    end

    def items_to_ignore
      @diff.select { |d| d.op == :ignore }
    end

    def items_to_exclude
      @diff.select { |d| d.op == :ignore and d.excluded == true }
    end

    def items_to_noop
      @diff.select { |d| d.op == :noop }
    end

    def items_to_change
      @diff.select { |d| [:delete, :update, :create].include?(d.op) }
    end

    def final_items
      case @mode
      when :push then @local
      when :pull then @remote
      end
    end

    def any_changes?
      self.items_to_change.count > 0
    end

    def print_report
      puts '='*85
      puts @target.description(@mode)

      puts "  Keys scanned: #{@diff.count}"
      if Constancy.config.verbose?
        puts "  Keys ignored: #{self.items_to_ignore.count}"
        puts "  Keys in sync: #{self.items_to_noop.count}"
      end

      puts if self.any_changes?

      from_content_key, to_content_key, to_path_key, to_type_display_name =
        case @mode
        when :push then [:local_content, :remote_content, :consul_key, "Keys"]
        when :pull
          case @target.type
          when :dir then [:remote_content, :local_content, :display_filename, "Files"]
          when :file then [:remote_content, :local_content, :display_filename, "File entries"]
          end
        end

      @diff.each do |item|
        case item.op
        when :create
          puts "CREATE".bold.green + " #{item[to_path_key]}"
          puts '-'*85
          # simulate diff but without complaints about line endings
          item[from_content_key].each_line do |line|
            puts "+#{line.chomp}".green
          end
          puts '-'*85

        when :update
          puts "UPDATE".bold + " #{item[to_path_key]}"
          puts '-'*85
          puts Diffy::Diff.new(item[to_content_key], item[from_content_key]).to_s(:color)
          puts '-'*85

        when :delete
          if @target.delete?
            puts "DELETE".bold.red + " #{item[to_path_key]}"
            puts '-'*85
            # simulate diff but without complaints about line endings
            item[to_content_key].each_line do |line|
              puts "-#{line.chomp}".red
            end
            puts '-'*85
          else
            if Constancy.config.verbose?
              puts "IGNORE".bold + " #{item[to_path_key]}"
            end
          end

        when :ignore
          if Constancy.config.verbose?
            puts "IGNORE".bold + " #{item[to_path_key]}"
          end

        when :noop
          if Constancy.config.verbose?
            puts "NO-OP!".bold + " #{item[to_path_key]}"
          end

        else
          if Constancy.config.verbose?
            STDERR.puts "WARNING: unexpected operation '#{item.op}' for #{item[to_path_key]}"
          end

        end
      end

      if self.items_to_create.count > 0
        puts
        puts "#{to_type_display_name} to create: #{self.items_to_create.count}".bold
        self.items_to_create.each do |item|
          puts "+ #{item[to_path_key]}".green
        end
      end

      if self.items_to_update.count > 0
        puts
        puts "#{to_type_display_name} to update: #{self.items_to_update.count}".bold
        self.items_to_update.each do |item|
          puts "~ #{item[to_path_key]}".blue
        end
      end

      if @target.delete?
        if self.items_to_delete.count > 0
          puts
          puts "#{to_type_display_name} to delete: #{self.items_to_delete.count}".bold
          self.items_to_delete.each do |item|
            puts "- #{item[to_path_key]}".red
          end
        end
      end
    end
  end
end
