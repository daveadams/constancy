# This software is public domain. No rights are reserved. See LICENSE for more information.

class Constancy
  class ConfigFileNotFound < RuntimeError; end
  class ConfigFileInvalid < RuntimeError; end
  class ConsulTokenRequired < RuntimeError; end
  class VaultConfigInvalid < RuntimeError; end

  class Config
    CONFIG_FILENAMES = %w( constancy.yml )
    VALID_CONFIG_KEYS = %w( sync consul vault constancy )
    VALID_CONSUL_CONFIG_KEYS = %w( url datacenter token_source )
    VALID_VAULT_CONFIG_KEYS = %w( url path field )
    VALID_CONSTANCY_CONFIG_KEYS = %w( verbose chomp delete color )
    DEFAULT_CONSUL_URL = "http://localhost:8500"
    DEFAULT_CONSUL_TOKEN_SOURCE = "none"
    DEFAULT_VAULT_FIELD = "token"

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

      # start with a token from the environment, regardless of the token_source setting
      consul_token = ENV['CONSUL_HTTP_TOKEN'] || ENV['CONSUL_TOKEN']

      case raw['consul']['token_source'] || Constancy::Config::DEFAULT_CONSUL_TOKEN_SOURCE
      when "none"
        # nothing to do

      when "env"
        if consul_token.nil? or consul_token == ""
          raise Constancy::ConsulTokenRequired.new("Consul token_source is set to 'env' but neither CONSUL_TOKEN nor CONSUL_HTTP_TOKEN is set")
        end

      when "vault"
        require 'vault'

        raw['vault'] ||= {}
        if not raw['vault'].is_a? Hash
          raise Constancy::ConfigFileInvalid.new("'vault' must be a hash")
        end

        if (raw['vault'].keys - Constancy::Config::VALID_VAULT_CONFIG_KEYS) != []
          raise Constancy::ConfigFileInvalid.new("Only the following keys are valid in the vault config: #{Constancy::Config::VALID_VAULT_CONFIG_KEYS.join(", ")}")
        end

        vault_path = raw['vault']['path']
        if vault_path.nil? or vault_path == ""
          raise Constancy::ConfigFileInvalid.new("vault.path must be specified to use vault as a token source")
        end

        # prioritize the config file over environment variables for vault address
        vault_addr = raw['vault']['url'] || ENV['VAULT_ADDR']
        if vault_addr.nil? or vault_addr == ""
          raise Constancy::VaultConfigInvalid.new("Vault address must be set in vault.url or VAULT_ADDR")
        end

        vault_token = ENV['VAULT_TOKEN']
        if vault_token.nil? or vault_token == ""
          vault_token_file = File.expand_path("~/.vault-token")
          if File.exist?(vault_token_file)
            vault_token = File.read(vault_token_file)
          else
            raise Constancy::VaultConfigInvalid.new("Vault token must be set in ~/.vault-token or VAULT_TOKEN")
          end
        end

        vault_field = raw['vault']['field'] || Constancy::Config::DEFAULT_VAULT_FIELD

        ENV['VAULT_ADDR'] = vault_addr
        ENV['VAULT_TOKEN'] = vault_token

        begin
          response = Vault.logical.read(vault_path)
          consul_token = response.data[vault_field.to_sym]

          if response.lease_id
            at_exit {
              begin
                Vault.sys.revoke(response.lease_id)
              rescue => e
                # this is fine
              end
            }
          end

        rescue => e
          raise Constancy::VaultConfigInvalid.new("Are you logged in to Vault?\n\n#{e}")
        end

        if consul_token.nil? or consul_token == ""
          raise Constancy::VaultConfigInvalid.new("Could not acquire a Consul token from Vault")
        end

      else
        raise Constancy::ConfigFileInvalid.new("Only the following values are valid for token_source: none, env, vault")
      end

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
