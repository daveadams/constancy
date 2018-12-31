## 0.3.0 (December 28, 2018)

**IMPROVEMENT**: Allow syncing a Consul key tree with a single local YAML (or JSON) file.

**IMPROVEMENT**: Pull mode to sync data from Consul to the filesystem.

**PERFORMANCE**: Refactored diff calculation to minimize repeated work.

## 0.2.2 (December 25, 2018)

**IMPROVEMENT**: Add Consul token source and Vault config details to 'constancy config' output.

**IMPROVEMENT**: Don't call external APIs (ie Vault) for 'constancy config' command.

## 0.2.1 (December 25, 2018)

**CHANGE**: Change vault config field names to be more explicit.

## 0.2.0 (December 24, 2018)

**IMPROVEMENT**: Add vault integration for fetching temporary Consul tokens.

## 0.1.5 (November 29, 2018)

**IMPROVEMENT**: Pass config file through ERB to allow dynamic configuration.

## 0.1.4 (August 14, 2018)

**BUG**: Force treating content as ASCII to properly deal with unencoded binary data. (@ccutrer)

## 0.1.3 (May 18, 2018)

**BUG**: Avoid creating dummy empty KV entries for a missing directory tree (@ccutrer)

**IMPROVEMENT**: Handle symlinks in filesystem paths (@ccutrer)

## 0.1.2 (March 12, 2018)

**BUG**: Treat nil remote key values as empty string for diffing

## 0.1.1 (March 12, 2018)

**BUG**: Fix Ruby syntax fail for failthru of default values (#1)

## 0.1.0 (February 1, 2018)

Initial release
