# constancy

Constancy is a simple, straightforward CLI tool for synchronizing data from the
filesystem to the Consul KV store and vice-versa.

## Basic Usage

Run `constancy check` to see what differences exist, and `constancy push` to
synchronize the changes from the filesystem to Consul.

    $ constancy check
    =====================================================================================
    myapp-private
    local:consul/private => consul:dc1:private/myapp
      Keys scanned: 37
    No changes to make for this sync target.

    =====================================================================================
    myapp-config
    local:consul/config => consul:dc1:config/myapp
      Keys scanned: 80

    UPDATE config/myapp/prod/ip-whitelist.json
    -------------------------------------------------------------------------------------
    -["10.8.0.0/16"]
    +["10.8.0.0/16","10.9.10.0/24"]
    -------------------------------------------------------------------------------------

    Keys to update: 1
    ~ config/myapp/prod/ip-whitelist.json

You can also limit your command to specific synchronization targets by using
the `--target` flag:

    $ constancy push --target myapp-config
    =====================================================================================
    myapp-config
    local:consul/config => consul:dc1:config/myapp
      Keys scanned: 80

    UPDATE config/myapp/prod/ip-whitelist.json
    -------------------------------------------------------------------------------------
    -["10.8.0.0/16"]
    +["10.8.0.0/16","10.9.10.0/24"]
    -------------------------------------------------------------------------------------

    Keys to update: 1
    ~ config/myapp/prod/ip-whitelist.json

    Do you want to push these changes?
      Enter 'yes' to continue: yes

    UPDATE config/myapp/prod/ip-whitelist.json   OK

Run `constancy --help` for additional options and commands.

## Pull Mode

Constancy can also sync _from_ Consul to the local filesystem. This can be
particularly useful for seeding a git repo with the current contents of a Consul
KV database.

Run `constancy check --pull` to get a summary of changes, and `constancy pull`
to actually sync the changes to the local filesystem. Additional arguments such
as `--target <name>` work in pull mode as well.


## Configuration

Constancy will automatically configure itself using the first `constancy.yml`
file it comes across when searching backwards through the directory tree from
the current working directory. So, typically you may wish to place the config
file in the root of your git repository or the base directory of your config
file tree.

You can also specify a config file using the `--config <filename>` command line
argument.


### Configuration file structure

The configuration file is a Hash represented in YAML format with three possible
top-level keys: `constancy`, `consul`, and `sync`. The `constancy` section sets
global defaults and app options. The `consul` section specifies the URL to the
Consul REST API endpoint. And the `sync` section lists the directories and
Consul prefixes you wish to synchronize. Only the `sync` section is strictly
required. An example `constancy.yml` is below including explanatory comments:

    # constancy.yml

    constancy:
      # verbose - defaults to `false`
      #   Set this to `true` for more verbose output.
      verbose: false

      # chomp - defaults to `true`
      #   Automatically runs `chomp` on the strings read in from files to
      #   eliminate a single trailing newline character (commonly inserted
      #   by text editors). Set to `false` to disable this by default for
      #   all sync targets (it can be overridden on a per-target basis).
      chomp: true

      # delete - defaults to `false`
      #   Set this to `true` to make the default for all sync targets to
      #   delete any keys found in Consul that do not have a corresponding
      #   file on disk. By default, extraneous remote keys will be ignored.
      #   If `verbose` is set to `true` the extraneous keys will be named
      #   in the output.
      delete: false

      # color - defaults to `true`
      #   Set this to `false` to disable colorized output (eg when running
      #   with an automated tool).
      color: true

    consul:
      # url - defaults to `http://localhost:8500`
      #   The REST API endpoint for the Consul agent.
      url: http://localhost:8500

      # datacenter - defaults to nil
      #   Set this to change the default datacenter for sync targets to
      #   something other than the datacenter of the Consul agent.
      datacenter: dc1

      # token_source - defaults to 'none'
      #   'none': expect no Consul token (although env vars will be used if they are set)
      #   'env': expect Consul token to be set in CONSUL_TOKEN or CONSUL_HTTP_TOKEN
      #   'vault': read Consul token from Vault based on settings in the 'vault' section

    # the vault section is only necessary if consul.token_source is set to 'vault'
    vault:
      # url - defaults to the value of VAULT_ADDR
      #   The REST API endpoint of your Vault server
      url: https://your.vault.example

      # consul_token_path - the path to the endpoint from which to read the Consul token
      #   The Vault URI path to the Consul token - can be either the Consul
      #   dynamic backend or a KV endpoint with a static value. If the dynamic
      #   backend is used, the lease will be automatically revoked when
      #   constancy exits.
      consul_token_path: consul/creds/my-role

      # consul_token_field - name of the field in which the Consul token is stored
      #   Defaults to 'token' which is the field used by the dynamic backend
      #   but can be set to something else for static values.
      consul_token_field: token

    sync:
      # sync is an array of hashes of sync target configurations
      #   Fields:
      #     name - The arbitrary friendly name of the sync target. Only
      #       required if you wish to target specific sync targets using
      #       the `--target` CLI flag.
      #     prefix - (required) The Consul KV prefix to synchronize to.
      #     type - (default: "dir") The type of local file storage. Either
      #       'dir' to indicate a directory tree of files corresponding to
      #       Consul keys; or 'file' to indicate a single YAML file with a
      #       map of relative key paths to values.
      #     datacenter - The Consul datacenter to synchronize to. If not
      #       specified, the `datacenter` setting in the `consul` section
      #       will be used. If that is also not specified, the sync will
      #       happen with the local datacenter of the Consul agent.
      #     path - (required) The relative filesystem path to either the
      #       directory containing the files with content to synchronize
      #       to Consul if this sync target has type=dir, or the local file
      #       containing a hash of remote keys if this sync target has
      #       type=file. This path is calculated relative to the directory
      #       containing the configuration file.
      #     delete - Whether or not to delete remote keys that do not exist
      #       in the local filesystem. This inherits the setting from the
      #       `constancy` section, or if not specified, defaults to `false`.
      #     chomp - Whether or not to chomp a single newline character off
      #       the contents of local files before synchronizing to Consul.
      #       This inherits the setting from the `constancy` section, or if
      #       not specified, defaults to `true`.
      #     exclude - An array of Consul KV paths to exclude from the
      #       sync process. These exclusions will be noted in output if the
      #       verbose mode is in effect, otherwise they will be silently
      #       ignored. At this time there is no provision for specifying
      #       prefixes or patterns. Each key must be fully and explicitly
      #       specified.
      - name: myapp-config
        prefix: config/myapp
        datacenter: dc1
        path: consul/config
        exclude:
          - config/myapp/beta/cowboy-yolo
          - config/myapp/prod/cowboy-yolo
      - name: myapp-private
        prefix: private/myapp
        type: dir
        datacenter: dc1
        path: consul/private
        delete: true
      - name: yourapp-config
        prefix: config/yourapp
        type: file
        datacenter: dc1
        path: consul/yourapp.yml
        delete: true

You can run `constancy config` to get a summary of the defined configuration
and to double-check config syntax.

### File sync targets

When using `type: file` for a sync target (see example above), the local path
should be a YAML (or JSON) file containing a hash of relative key paths to the
contents of those keys. So for example, given this configuration:

    sync:
      - name: config
        prefix: config/yourapp
        type: file
        datacenter: dc1
        path: yourapp.yml

If the file `yourapp.yml` has the following content:

    ---
    prod/dbname: yourapp
    prod/message: |
      Hello, world. This is a multiline message.
      I hope you like it.
      Thanks,
      YourApp
    prod/app/config.json: |
      {
        "port": 8080,
        "listen": "0.0.0.0",
        "enabled": true
      }
    prod:
      _: awesome value # the special _ key gets dropped and allows you to set a value for 'prod' and still nest stuff under it
      redis:
        port: 6380 # This gets flattened down to 'prod/redis/port' before getting sent along

Then `constancy push` will attempt to create and/or update the following keys
with the corresponding content from `yourapp.yml`:

    config/yourapp/prod/dbname
    config/yourapp/prod/message
    config/yourapp/prod/app/config.json

Likewise, a `constancy pull` operation will work in reverse, and pull values
from any keys under `config/yourapp/` into the file `yourapp.yml`, overwriting
whatever values are there.

Note that JSON is also supported for this file for `push` operations, given that
YAML parsers will correctly parse JSON. However, `constancy pull` will only
write out YAML in the current version.

Also important to note that any comments in the YAML file will be lost on a
`pull` operation that updates a file sync target.


### Dynamic configuration

The configuration file will be rendered through ERB before being parsed as
YAML. This can be useful for avoiding repetitive configuration across multiple
prefixes or datacenters, eg:

    sync:
    <% %w( dc1 dc2 dc3 ).each do |dc| %>
      - name: <%= dc %>:myapp-private
        prefix: private/myapp
        datacenter: <%= dc %>
        path: consul/<%= dc %>/private
        delete: true
    <% end %>

It's a good idea to sanity-check your ERB by running `constancy config` after
making any changes.


### Environment configuration

Constancy may be partially configured using environment variables:
* `CONSTANCY_VERBOSE` - set this variable to any value to enable verbose mode
* `CONSUL_HTTP_TOKEN` or `CONSUL_TOKEN` - use one of these variables (priority
  is given to `CONSUL_HTTP_TOKEN`) to set an explicit Consul token to use when
  interacting with the API. Otherwise, by default the agent's `acl_token`
  setting is used implicitly.
* `VAULT_ADDR` and `VAULT_TOKEN` - if `consul.token_source` is set to `vault`
  these variables are used to authenticate to Vault. If `VAULT_TOKEN` is not
  set, Constancy will attempt to read a token from `~/.vault-token`. If the
  `url` field is set, it will take priority over the `VAULT_ADDR` environment
  variable, but one or the other must be set.


## Roadmap

Constancy is relatively new software. There's more to be done. Some ideas, which
may or may not ever be implemented:

* Using CAS to verify the key has not changed in the interim before updating/deleting
* Automation support for running non-interactively
* Pattern- and prefix-based exclusions
* Logging of changes to files, syslog, other services
* Other commands to assist in managing Consul KV sets
* Git awareness (branches, commit state, etc)
* Automated tests
* Submitting changes in batches using transactions


## Contributing

I'm happy to accept suggestions, bug reports, and pull requests through Github.


## License

This software is public domain. No rights are reserved. See LICENSE for more
information.
