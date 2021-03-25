# Changelog

## Release 0.7.0

### New features

* **Provide credentials as parameters**
  ([#17](https://github.com/puppetlabs/puppetlabs-aws_inventory/pull/17))

  The `resolve_reference` task has new `aws_access_key_id` and `aws_secret_access_key`
  parameters for authenticating with AWS.

## Release 0.6.0

### New features

* **Bump maximum Puppet version to include 7.x**

## Release 0.5.2

### Bug fixes

* **Add PDK as a gem dependency**

  PDK is now a gem dependency for the module release pipeline

## Release 0.5.1

### Bug fixes

* **Add missing dependencies to module metadata**
  ([#10](https://github.com/puppetlabs/puppetlabs-aws_inventory/pull/11))

  The module metadata now includes `ruby_plugin_helper` and `ruby_task_helper`
  as dependencies.

## Release 0.5.0

### Bug fixes

* **Reference tags in target_mapping** ([#9](https://github.com/puppetlabs/puppetlabs-aws_inventory/pull/9))

  Previously, the tags attribute couldn't be effectively used in
  target_mapping because it contains an array of maps with "key" and
  "value" fields. We now convert the tags attribute into a standard key/value map so
  that tags can be looked up using `tags.Name` syntax.

## Release 0.4.0

### New features

* **Set `resolve_reference` task to private** ([#6](https://github.com/puppetlabs/puppetlabs-aws_inventory/pull/6))

    The `resolve_reference` task has been set to `private` so it no longer appears in UI lists.
    
## Release 0.3.0

### New features

* **Added `target_mapping` parameter in `resolve_reference` task** ([#1407](https://github.com/puppetlabs/bolt/issues/1407))

  The `resolve_reference` task has a new `target_mapping` parameter that accepts a hash of target attributes and the resource values to populate them with.

## Release 0.2.0

### Bug fixes

* **Expand `credentials` path relative to Boltdir** ([#1162](https://github.com/puppetlabs/bolt/issues/1162))

  The `credentials` option will now be expanded relative to the active Boltdir the user is running bolt with, instead of the current working directory they ran Bolt from. This is part of standardizing all configurable paths in Bolt to be relative to the Boltdir.

## Release 0.1.0

This is the initial release.
