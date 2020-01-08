## 0.3.3 (January 8, 2020)

* Remove repeated `/` in Consul paths

## 0.3.2 (June 20, 2019)

* Allow skipping the confirmation prompt for the `push` and `pull` commands by
  passing `--yes`

## 0.3.1 (March 9, 2019)

* Support more flexible key specification in file targets (@tpickett66) (#4)
* Improve README documentation for file targets
* Add a 'targets' command
* **BUG**: Force convert local values from file targets to strings

## 0.3.0 (December 28, 2018)

* Allow syncing a Consul key tree with a single local YAML (or JSON) file.
* Pull mode to sync data from Consul to the filesystem.
* Refactored diff calculation to minimize repeated work.

## 0.2.2 (December 25, 2018)

* Add Consul token source and Vault config details to 'constancy config' output.
* Don't call external APIs (ie Vault) for 'constancy config' command.

## 0.2.1 (December 25, 2018)

* Change vault config field names to be more explicit.

## 0.2.0 (December 24, 2018)

* Add vault integration for fetching temporary Consul tokens.

## 0.1.5 (November 29, 2018)

* Pass config file through ERB to allow dynamic configuration.

## 0.1.4 (August 14, 2018)

* **BUG**: Force treating content as ASCII to properly deal with unencoded binary data. (@ccutrer) (#3)

## 0.1.3 (May 18, 2018)

* **BUG**: Avoid creating dummy empty KV entries for a missing directory tree (@ccutrer) (#2)
* Handle symlinks in filesystem paths (@ccutrer) (#2)

## 0.1.2 (March 12, 2018)

* **BUG**: Treat nil remote key values as empty string for diffing

## 0.1.1 (March 12, 2018)

* **BUG**: Fix Ruby syntax fail for failthru of default values (#1)

## 0.1.0 (February 1, 2018)

* Initial release
