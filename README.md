# constancy

Constancy provides simple filesystem-to-Consul KV synchronization.

## Basic Usage

Run `constancy check` to see what differences exist, and `constancy push` to
synchronize the changes.

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

    sync:
      # sync is an array of hashes of sync target configurations
      #   Fields:
      #     name - The arbitrary friendly name of the sync target. Only
      #       required if you wish to target specific sync targets using
      #       the `--target` CLI flag.
      #     prefix - (required) The Consul KV prefix to synchronize to.
      #     datacenter - The Consul datacenter to synchronize to. If not
      #       specified, the `datacenter` setting in the `consul` section
      #       will be used. If that is also not specified, the sync will
      #       happen with the local datacenter of the Consul agent.
      #     path - (required) The relative filesystem path to the directory
      #       containing the files with content to synchronize to Consul.
      #       This path is calculated relative to the directory containing
      #       the configuration file.
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
        datacenter: dc1
        path: consul/private
        delete: true

You can run `constancy config` to get a summary of the defined configuration
and to double-check config syntax.


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


## Automation

For version 0.1, Constancy does not fully support running non-interactively.
This is primarily to ensure human observation of any changes being made while
the software matures. Later versions will allow for full automation.


## Roadmap

Constancy is very new software. There's more to be done. Some ideas:

* Pattern- and prefix-based exclusions
* Other commands to assist in managing Consul KV sets
* Automation support for running non-interactively
* Git awareness (branches, commit state, etc)
* Automated tests
* Logging of changes to files, syslog, other services
* Allowing other means of providing a Consul token
* Pull mode to sync from Consul to local filesystem
* Using CAS to verify the key has not changed in the interim before updating/deleting
* Submitting changes in batches using transactions


## Contributing

I'm happy to accept suggestions, bug reports, and pull requests through Github.


## License

This software is public domain. No rights are reserved. See LICENSE for more
information.
