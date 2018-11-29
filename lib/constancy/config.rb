# This software is public domain. No rights are reserved. See LICENSE for more information.

class Constancy
  class ConfigFileNotFound < RuntimeError; end
  class ConfigFileInvalid < RuntimeError; end

  class Config
    CONFIG_FILENAMES = %w( constancy.yml )
    VALID_CONFIG_KEYS = %w( sync consul constancy )
    VALID_CONSUL_CONFIG_KEYS = %w( url datacenter )
    VALID_CONSTANCY_CONFIG_KEYS = %w( verbose chomp delete color )
    DEFAULT_CONSUL_URL = "http://localhost:8500"

    attr_accessor :config_file, :base_dir, :consul, :sync_targets, :target_whitelist

    class << self
      # discover the nearest config file
      def discover(dir: nil)
        dir ||= Dir.pwd

        CONFIG_FILENAMES.each do |filename|
          full_path = File.join(dir, filename)
          if File.exist?(full_path)
            return full_path
          end
        end

        dir == "/" ? nil : self.discover(dir: File.dirname(dir))
      end
    end

    def initialize(path: nil, targets: nil)
      if path.nil? or File.directory?(path)
        self.config_file = Constancy::Config.discover(dir: path)
      elsif File.exist?(path)
        self.config_file = path
      else
        raise Constancy::ConfigFileNotFound.new
      end

      if self.config_file.nil? or not File.exist?(self.config_file) or not File.readable?(self.config_file)
        raise Constancy::ConfigFileNotFound.new
      end

      self.config_file = File.expand_path(self.config_file)
      self.base_dir = File.dirname(self.config_file)
      self.target_whitelist = targets
      parse!
    end

    def verbose?
      @is_verbose
    end

    def chomp?
      @do_chomp
    end

    def delete?
      @do_delete
    end

    def color?
      @use_color
    end

    private

    def parse!
      raw = {}
      begin
        raw = YAML.load(ERB.new(File.read(self.config_file)).result)
      rescue
        raise Constancy::ConfigFileInvalid.new("Unable to parse config file as YAML")
      end

      if raw.is_a? FalseClass
        # this generally means an empty config file
        raw = {}
      end

      if not raw.is_a? Hash
        raise Constancy::ConfigFileInvalid.new("Config file must form a hash")
      end

      if (raw.keys - Constancy::Config::VALID_CONFIG_KEYS) != []
        raise Constancy::ConfigFileInvalid.new("Only the following keys are valid at the top level of the config: #{Constancy::Config::VALID_CONFIG_KEYS.join(", ")}")
      end

      raw['consul'] ||= {}
      if not raw['consul'].is_a? Hash
        raise Constancy::ConfigFileInvalid.new("'consul' must be a hash")
      end

      if (raw['consul'].keys - Constancy::Config::VALID_CONSUL_CONFIG_KEYS) != []
        raise Constancy::ConfigFileInvalid.new("Only the following keys are valid in the consul config: #{Constancy::Config::VALID_CONSUL_CONFIG_KEYS.join(", ")}")
      end

      consul_url = raw['consul']['url'] || Constancy::Config::DEFAULT_CONSUL_URL
      consul_token = ENV['CONSUL_HTTP_TOKEN'] || ENV['CONSUL_TOKEN']
      self.consul = Imperium::Configuration.new(url: consul_url, token: consul_token)

      raw['constancy'] ||= {}
      if not raw['constancy'].is_a? Hash
        raise Constancy::ConfigFileInvalid.new("'constancy' must be a hash")
      end

      if (raw['constancy'].keys - Constancy::Config::VALID_CONSTANCY_CONFIG_KEYS) != []
        raise Constancy::ConfigFileInvalid.new("Only the following keys are valid in the 'constancy' config block: #{Constancy::Config::VALID_CONSTANCY_CONFIG_KEYS.join(", ")}")
      end

      # verbose: default false
      @is_verbose = raw['constancy']['verbose'] ? true : false
      if ENV['CONSTANCY_VERBOSE']
        @is_verbose = true
      end

      # chomp: default true
      if raw['constancy'].has_key?('chomp')
        @do_chomp = raw['constancy']['chomp'] ? true : false
      else
        @do_chomp = true
      end

      # delete: default false
      @do_delete = raw['constancy']['delete'] ? true : false

      raw['sync'] ||= []
      if not raw['sync'].is_a? Array
        raise Constancy::ConfigFileInvalid.new("'sync' must be an array")
      end

      # color: default true
      if raw['constancy'].has_key?('color')
        @use_color = raw['constancy']['color'] ? true : false
      else
        @use_color = true
      end

      self.sync_targets = []
      raw['sync'].each do |target|
        if target.is_a? Hash
          target['datacenter'] ||= raw['consul']['datacenter']
          if target['chomp'].nil?
            target['chomp'] = self.chomp?
          end
          if target['delete'].nil?
            target['delete'] = self.delete?
          end
        end

        if not self.target_whitelist.nil?
          # unnamed targets cannot be whitelisted
          next if target['name'].nil?

          # named targets must be on the whitelist
          next if not self.target_whitelist.include?(target['name'])
        end

        self.sync_targets << Constancy::SyncTarget.new(config: target, imperium_config: self.consul)
      end

    end
  end
end
