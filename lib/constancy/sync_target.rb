# This software is public domain. No rights are reserved. See LICENSE for more information.

class Constancy
  class SyncTarget
    VALID_CONFIG_KEYS = %w( name datacenter prefix path exclude chomp delete )
    attr_accessor :name, :datacenter, :prefix, :path, :exclude, :consul

    REQUIRED_CONFIG_KEYS = %w( prefix )

    def initialize(config:, imperium_config:)
      if not config.is_a? Hash
        raise Constancy::ConfigFileInvalid.new("Sync target entries must be specified as hashes")
      end

      if (config.keys - Constancy::SyncTarget::VALID_CONFIG_KEYS) != []
        raise Constancy::ConfigFileInvalid.new("Only the following keys are valid in a sync target entry: #{Constancy::SyncTarget::VALID_CONFIG_KEYS.join(", ")}")
      end

      if (Constancy::SyncTarget::REQUIRED_CONFIG_KEYS - config.keys) != []
        raise Constancy::ConfigFileInvalid.new("The following keys are required for a sync target entry: #{Constancy::SyncTarget::REQUIRED_CONFIG_KEYS.join(", ")}")
      end

      self.datacenter = config['datacenter']
      self.prefix = config['prefix']
      self.path = config['path'] || config['prefix']
      self.name = config['name']
      self.exclude = config['exclude'] || []
      if config.has_key?('chomp')
        @do_chomp = config['chomp'] ? true : false
      end
      if config.has_key?('delete')
        @do_delete = config['delete'] ? true : false
      else
        @do_delete = false
      end

      self.consul = Imperium::KV.new(imperium_config)
    end

    def chomp?
      @do_chomp
    end

    def delete?
      @do_delete
    end

    def description
      "#{self.name.nil? ? '' : self.name.bold + "\n"}#{'local'.blue}:#{self.path} => #{'consul'.cyan}:#{self.datacenter.green}:#{self.prefix}"
    end

    def clear_cache
      @base_dir = nil
      @local_files = nil
      @local_items = nil
      @remote_items = nil
    end

    def base_dir
      @base_dir ||= File.join(Constancy.config.base_dir, self.path)
    end

    def local_files
      @local_files ||= Dir["#{self.base_dir}/**/*"].select { |f| File.file?(f) }
    end

    def local_items
      return @local_items if not @local_items.nil?
      @local_items = {}

      self.local_files.each do |local_file|
        @local_items[local_file.sub(%r{^#{self.base_dir}/?}, '')] = if self.chomp?
                                                                      File.read(local_file).chomp
                                                                    else
                                                                      File.read(local_file)
                                                                    end
      end

      @local_items
    end

    def remote_items
      return @remote_items if not @remote_items.nil?
      @remote_items = {}

      resp = self.consul.get(self.prefix, :recurse, dc: self.datacenter)

      Constancy::Util.flatten_hash(resp.values).each_pair do |key, value|
        @remote_items[key.join("/")] = value
      end

      @remote_items
    end

    def diff
      local = self.local_items
      remote = self.remote_items
      all_keys = (local.keys + remote.keys).sort.uniq

      all_keys.collect do |key|
        excluded = false
        op = :noop
        if remote.has_key?(key) and not local.has_key?(key)
          if self.delete?
            op = :delete
          else
            op = :ignore
          end
        elsif local.has_key?(key) and not remote.has_key?(key)
          op = :create
        else
          if remote[key] == local[key]
            op = :noop
          else
            op = :update
          end
        end

        consul_key = [self.prefix, key].compact.join("/")

        if self.exclude.include?(key) or self.exclude.include?(consul_key)
          op = :ignore
          excluded = true
        end

        {
          :op => op,
          :excluded => excluded,
          :relative_path => key,
          :filename => File.join(self.base_dir, key),
          :consul_key => consul_key,
          :local_content => local[key],
          :remote_content => remote[key],
        }
      end
    end

    def items_to_delete
      self.diff.select { |d| d[:op] == :delete }
    end

    def items_to_update
      self.diff.select { |d| d[:op] == :update }
    end

    def items_to_create
      self.diff.select { |d| d[:op] == :create }
    end

    def items_to_ignore
      self.diff.select { |d| d[:op] == :ignore }
    end

    def items_to_exclude
      self.diff.select { |d| d[:op] == :ignore and d[:excluded] == true }
    end

    def items_to_noop
      self.diff.select { |d| d[:op] == :noop }
    end

    def items_to_change
      self.diff.select { |d| [:delete, :update, :create].include?(d[:op]) }
    end

    def any_changes?
      self.items_to_change.count > 0
    end

    def print_report
      puts '='*85
      puts self.description

      puts "  Keys scanned: #{self.diff.count}"
      if Constancy.config.verbose?
        puts "  Keys ignored: #{self.items_to_ignore.count}"
        puts "  Keys in sync: #{self.items_to_noop.count}"
      end

      puts if self.any_changes?

      self.diff.each do |item|
        case item[:op]
        when :create
          puts "CREATE".bold.green + " #{item[:consul_key]}"
          puts '-'*85
          # simulate diff but without complaints about line endings
          item[:local_content].each_line do |line|
            puts "+#{line.chomp}".green
          end
          puts '-'*85

        when :update
          puts "UPDATE".bold + " #{item[:consul_key]}"
          puts '-'*85
          puts Diffy::Diff.new(item[:remote_content], item[:local_content]).to_s(:color)
          puts '-'*85

        when :delete
          if self.delete?
            puts "DELETE".bold.red + " #{item[:consul_key]}"
            puts '-'*85
            # simulate diff but without complaints about line endings
            item[:remote_content].each_line do |line|
              puts "-#{line.chomp}".red
            end
            puts '-'*85
          else
            if Constancy.config.verbose?
              puts "IGNORE".bold + " #{item[:consul_key]}"
            end
          end

        when :ignore
          if Constancy.config.verbose?
            puts "IGNORE".bold + " #{item[:consul_key]}"
          end

        when :noop
          if Constancy.config.verbose?
            puts "NO-OP!".bold + " #{item[:consul_key]}"
          end

        else
          if Constancy.config.verbose?
            STDERR.puts "WARNING: unexpected operation '#{item[:op]}' for #{item[:consul_key]}"
          end

        end
      end

      if self.items_to_create.count > 0
        puts
        puts "Keys to create: #{self.items_to_create.count}".bold
        self.items_to_create.each do |item|
          puts "+ #{item[:consul_key]}".green
        end
      end

      if self.items_to_update.count > 0
        puts
        puts "Keys to update: #{self.items_to_update.count}".bold
        self.items_to_update.each do |item|
          puts "~ #{item[:consul_key]}".blue
        end
      end

      if self.delete?
        if self.items_to_delete.count > 0
          puts
          puts "Keys to delete: #{self.items_to_delete.count}".bold
          self.items_to_delete.each do |item|
            puts "- #{item[:consul_key]}".red
          end
        end
      end
    end
  end
end
