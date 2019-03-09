# This software is public domain. No rights are reserved. See LICENSE for more information.

class Constancy
  class SyncTarget
    VALID_CONFIG_KEYS = %w( name type datacenter prefix path exclude chomp delete )
    attr_accessor :name, :type, :datacenter, :prefix, :path, :exclude, :consul

    REQUIRED_CONFIG_KEYS = %w( prefix )
    VALID_TYPES = [ :dir, :file ]
    DEFAULT_TYPE = :dir

    def initialize(config:, imperium_config:, base_dir:)
      if not config.is_a? Hash
        raise Constancy::ConfigFileInvalid.new("Sync target entries must be specified as hashes")
      end

      if (config.keys - Constancy::SyncTarget::VALID_CONFIG_KEYS) != []
        raise Constancy::ConfigFileInvalid.new("Only the following keys are valid in a sync target entry: #{Constancy::SyncTarget::VALID_CONFIG_KEYS.join(", ")}")
      end

      if (Constancy::SyncTarget::REQUIRED_CONFIG_KEYS - config.keys) != []
        raise Constancy::ConfigFileInvalid.new("The following keys are required in a sync target entry: #{Constancy::SyncTarget::REQUIRED_CONFIG_KEYS.join(", ")}")
      end

      @base_dir = base_dir
      self.datacenter = config['datacenter']
      self.prefix = config['prefix']
      self.path = config['path'] || config['prefix']
      self.name = config['name']
      self.type = (config['type'] || Constancy::SyncTarget::DEFAULT_TYPE).to_sym
      unless Constancy::SyncTarget::VALID_TYPES.include?(self.type)
        raise Constancy::ConfigFileInvalid.new("Sync target '#{self.name || self.path}' has type '#{self.type}'. But only the following types are valid: #{Constancy::SyncTarget::VALID_TYPES.collect(&:to_s).join(", ")}")
      end

      if self.type == :file and File.directory?(self.base_path)
        raise Constancy::ConfigFileInvalid.new("Sync target '#{self.name || self.path}' has type 'file', but path '#{self.path}' is a directory.")
      end

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

    def description(mode = :push)
      if mode == :pull
        "#{self.name.nil? ? '' : self.name.bold + "\n"}#{'consul'.cyan}:#{self.datacenter.green}:#{self.prefix} => #{'local'.blue}:#{self.path}"
      else
        "#{self.name.nil? ? '' : self.name.bold + "\n"}#{'local'.blue}:#{self.path} => #{'consul'.cyan}:#{self.datacenter.green}:#{self.prefix}"
      end
    end

    def clear_cache
      @base_path = nil
      @local_files = nil
      @local_items = nil
      @remote_items = nil
    end

    def base_path
      @base_path ||= File.join(@base_dir, self.path)
    end

    def local_files
      # see https://stackoverflow.com/questions/357754/can-i-traverse-symlinked-directories-in-ruby-with-a-glob
      @local_files ||= Dir["#{self.base_path}/**{,/*/**}/*"].select { |f| File.file?(f) }
    end

    def local_items
      return @local_items if not @local_items.nil?
      @local_items = {}

      case self.type
      when :dir
        self.local_files.each do |local_file|
          @local_items[local_file.sub(%r{^#{self.base_path}/?}, '')] =
            if self.chomp?
              File.read(local_file).chomp.force_encoding(Encoding::ASCII_8BIT)
            else
              File.read(local_file).force_encoding(Encoding::ASCII_8BIT)
            end
        end

      when :file
        if File.exist?(self.base_path)
          @local_items = flatten_hash(nil, YAML.load_file(self.base_path))
        end
      end

      @local_items
    end

    def remote_items
      return @remote_items if not @remote_items.nil?
      @remote_items = {}

      resp = self.consul.get(self.prefix, :recurse, dc: self.datacenter)

      return @remote_items if resp.values.nil?
      Constancy::Util.flatten_hash(resp.values).each_pair do |key, value|
        @remote_items[key.join("/")] = (value.nil? ? '' : value)
      end

      @remote_items
    end

    def diff(mode)
      Constancy::Diff.new(target: self, local: self.local_items, remote: self.remote_items, mode: mode)
    end

    private def flatten_hash(prefix, hash)
      new_hash = {}

      hash.each do |k, v|
        if k == '_' && !prefix.nil?
          new_key = prefix
        else
          new_key = [prefix, k].compact.join('/')
        end

        case v
        when Hash
          new_hash.merge!(flatten_hash(new_key, v))
        else
          new_hash[new_key] = v.to_s
        end
      end

      new_hash
    end
  end
end
