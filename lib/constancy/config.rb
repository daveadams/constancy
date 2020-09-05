# This software is public domain. No rights are reserved. See LICENSE for more information.

require 'ostruct'

class Constancy
  class ConfigFileNotFound < RuntimeError; end
  class ConfigFileInvalid < RuntimeError; end
  class ConsulTokenRequired < RuntimeError; end
  class VaultConfigInvalid < RuntimeError; end

  class Config
    CONFIG_FILENAMES = %w( constancy.yml )
    VALID_CONFIG_KEYS = %w( sync consul vault constancy )
    VALID_VAULT_KEY_PATTERNS = [ %r{^vault\.[A-Za-z][A-Za-z0-9_-]*$}, %r{^vault$} ]
    VALID_CONFIG_KEY_PATTERNS = VALID_VAULT_KEY_PATTERNS
    VALID_CONSUL_CONFIG_KEYS = %w( url datacenter token_source )
    VALID_VAULT_CONFIG_KEYS = %w( url consul_token_path consul_token_field )
    VALID_CONSTANCY_CONFIG_KEYS = %w( verbose chomp delete color )
    DEFAULT_CONSUL_URL = "http://localhost:8500"
    DEFAULT_CONSUL_TOKEN_SOURCE = "none"
    DEFAULT_VAULT_CONSUL_TOKEN_FIELD = "token"

    attr_accessor :config_file, :base_dir, :consul_url, :default_consul_token_source,
      :sync_targets, :target_allowlist, :call_external_apis, :consul_token_sources

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

      def only_valid_config_keys!(keylist)
        (keylist - VALID_CONFIG_KEYS).each do |key|
          if not VALID_CONFIG_KEY_PATTERNS.find { |pattern| key =~ pattern }
            raise Constancy::ConfigFileInvalid.new("'#{key}' is not a valid configuration key")
          end
        end
        true
      end
    end

    def initialize(path: nil, targets: nil, call_external_apis: true)
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
      self.target_allowlist = targets
      self.call_external_apis = call_external_apis
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

    def parse_vault_token_sources!(raw)
      raw.keys.select { |key| VALID_VAULT_KEY_PATTERNS.find { |pattern| key =~ pattern } }.collect do |key|
        [key, Constancy::VaultTokenSource.new(name: key, config: raw[key])]
      end.to_h
    end

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

      Constancy::Config.only_valid_config_keys!(raw.keys)

      self.consul_token_sources = {
        "none" => Constancy::PassiveTokenSource.new,
        "env" => Constancy::EnvTokenSource.new,
      }.merge(
        self.parse_vault_token_sources!(raw),
      )

      raw['consul'] ||= {}
      if not raw['consul'].is_a? Hash
        raise Constancy::ConfigFileInvalid.new("'consul' must be a hash")
      end

      if (raw['consul'].keys - VALID_CONSUL_CONFIG_KEYS) != []
        raise Constancy::ConfigFileInvalid.new("Only the following keys are valid in the consul config: #{VALID_CONSUL_CONFIG_KEYS.join(", ")}")
      end

      self.consul_url = raw['consul']['url'] || DEFAULT_CONSUL_URL
      srcname = raw['consul']['token_source'] || DEFAULT_CONSUL_TOKEN_SOURCE
      self.default_consul_token_source =
        self.consul_token_sources[srcname].tap do |src|
          if src.nil?
            raise Constancy::ConfigFileInvalid.new("Consul token source '#{consul_token_source}' is not defined")
          end
        end

      raw['constancy'] ||= {}
      if not raw['constancy'].is_a? Hash
        raise Constancy::ConfigFileInvalid.new("'constancy' must be a hash")
      end

      if (raw['constancy'].keys - VALID_CONSTANCY_CONFIG_KEYS) != []
        raise Constancy::ConfigFileInvalid.new("Only the following keys are valid in the 'constancy' config block: #{VALID_CONSTANCY_CONFIG_KEYS.join(", ")}")
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
        token_source = self.default_consul_token_source
        if target.is_a? Hash
          target['datacenter'] ||= raw['consul']['datacenter']
          if target['chomp'].nil?
            target['chomp'] = self.chomp?
          end
          if target['delete'].nil?
            target['delete'] = self.delete?
          end
          if not target['token_source'].nil?
            token_source = self.consul_token_sources[target['token_source']]
            if token_source.nil?
              raise Constancy::ConfigFileInvalid.new("Consul token source '#{target['token_source']}' is not defined")
            end
            target.delete('token_source')
          end
        end

        if not self.target_allowlist.nil?
          # unnamed targets cannot be allowlisted
          next if target['name'].nil?

          # named targets must be on the allowlist
          next if not self.target_allowlist.include?(target['name'])
        end

        # only try to fetch consul tokens if we are actually going to do work
        consul_token = if self.call_external_apis
                         token_source.consul_token
                       else
                         ""
                       end
        self.sync_targets << Constancy::SyncTarget.new(config: target, consul_url: consul_url, token_source: token_source, base_dir: self.base_dir, call_external_apis: self.call_external_apis)
      end
    end
  end
end
