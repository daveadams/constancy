# This software is public domain. No rights are reserved. See LICENSE for more information.

class Constancy
  # use env vars if defined, but otherwise just return an empty string
  class PassiveTokenSource
    def name
      "none"
    end

    def consul_token
      ENV['CONSUL_HTTP_TOKEN'] || ENV['CONSUL_TOKEN'] || ""
    end
  end

  # use env vars and raise an error if none is found
  class EnvTokenSource
    def name
      "env"
    end

    def consul_token
      consul_token = ENV['CONSUL_HTTP_TOKEN'] || ENV['CONSUL_TOKEN']
      if consul_token.nil? or consul_token == ""
        raise Constancy::ConsulTokenRequired.new("Consul token_source was set to 'env' but neither CONSUL_TOKEN nor CONSUL_HTTP_TOKEN is set")
      end
    end
  end

  class VaultTokenSource
    attr_accessor :name, :vault_addr, :vault_token, :consul_token_path, :consul_token_field

    def initialize(name:, config:)
      self.name = name

      config ||= {}
      if not config.is_a? Hash
        raise Constancy::ConfigFileInvalid.new("'#{name}' must be a hash")
      end

      if (config.keys - Constancy::Config::VALID_VAULT_CONFIG_KEYS) != []
        raise Constancy::ConfigFileInvalid.new("Only the following keys are valid in a vault config: #{Constancy::Config::VALID_VAULT_CONFIG_KEYS.join(", ")}")
      end

      self.consul_token_path = config['consul_token_path']
      if self.consul_token_path.nil? or self.consul_token_path == ""
        raise Constancy::ConfigFileInvalid.new("consul_token_path must be specified to use '#{name}' as a token source")
      end

      # prioritize the config file over environment variables for vault address
      self.vault_addr = config['url'] || ENV['VAULT_ADDR']
      if self.vault_addr.nil? or self.vault_addr == ""
        raise Constancy::VaultConfigInvalid.new("Vault address must be set in #{name}.vault_addr or VAULT_ADDR")
      end

      self.vault_token = ENV['VAULT_TOKEN']
      if self.vault_token.nil? or self.vault_token == ""
        vault_token_file = File.expand_path("~/.vault-token")
        if File.exist?(vault_token_file)
          self.vault_token = File.read(vault_token_file)
        else
          raise Constancy::VaultConfigInvalid.new("Vault token must be set in ~/.vault-token or VAULT_TOKEN")
        end
      end

      self.consul_token_field = config['consul_token_field'] || Constancy::Config::DEFAULT_VAULT_CONSUL_TOKEN_FIELD
    end

    def consul_token
      if @consul_token.nil?
        begin
          response = Vault::Client.new(address: self.vault_addr, token: self.vault_token).logical.read(self.consul_token_path)
          @consul_token = response.data[self.consul_token_field.to_sym]
          if response.lease_id
            at_exit {
              begin
                Vault::Client.new(address: self.vault_addr, token: self.vault_token).sys.revoke(response.lease_id)
              rescue => e
                # this is fine
              end
            }
          end

        rescue => e
          raise Constancy::VaultConfigInvalid.new("Are you logged in to Vault?\n\n#{e}")
        end

        if @consul_token.nil? or @consul_token == ""
          raise Constancy::VaultConfigInvalid.new("Could not acquire a Consul token from Vault")
        end
      end
      @consul_token
    end
  end
end
