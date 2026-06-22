# aws_inventory

#### Table of Contents

1. [Description](#description)
2. [Requirements](#requirements)
3. [Usage](#usage)

## Description

This module includes a Bolt plugin to generate Bolt targets from AWS EC2 instances.

## Requirements

You will need an `aws_access_key_id` and a `aws_secret_access_key` (see [providing aws credentials](https://docs.aws.amazon.com/amazonswf/latest/awsrbflowguide/set-up-creds.html)) in order to authenticate against aws API.

## Usage

The AWS Inventory plugin supports looking up running AWS EC2 instances. It supports several fields:

-   `profile`: The [named profile](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-profiles.html) to use when loading from AWS `config` and `credentials` files. (optional, defaults to `default`)
-   `region`: The region to look up EC2 instances from.
-   `credentials`: The path to an AWS credentials file to load. (optional, defaults to `~/.aws/credentials`)
-   `credential_process`: An [external credentials process command](https://docs.aws.amazon.com/cli/latest/topic/config-vars.html#sourcing-credentials-from-external-processes) used to obtain session credentials. (optional)
-   `aws_access_key_id`: The AWS access key id to use. (optional)
-   `aws_secret_access_key`: The AWS secret access key to use. (optional)
-   `filters`: The [filter request parameters](https://docs.aws.amazon.com/AWSEC2/latest/APIReference/API_DescribeInstances.html) used to filter the EC2 instances by. Filters are name-values pairs, where the name is a request parameter and the values are an array of values to filter by. (optional)
-   `target_mapping`: A hash of target attributes to populate with resource values. Tags can referenced with tag.\<key\> (e.g. tag.Name). The following attributes are available.
    - `config`: A bolt config map where the value for each config setting is an [EC2 instance attribute](https://docs.aws.amazon.com/sdkforruby/api/Aws/EC2/Instance.html).
    - `name`: The [EC2 instance attribute](https://docs.aws.amazon.com/sdkforruby/api/Aws/EC2/Instance.html) to use as the target name.
    - `uri`: The [EC2 instance attribute](https://docs.aws.amazon.com/sdkforruby/api/Aws/EC2/Instance.html) to use as the target URI.

> **Note:** One of `uri` or `name` is required. If only `uri` is set, then the value of `uri` will be used as the `name`.

Accessing EC2 instances requires a region and valid credentials to be specified. The following locations are searched in order until a value is found:

**Region**

In order of precedence:

-   `region: <region>` in the inventory or config file
-   `ENV['AWS_REGION']`
-   `~/.aws/credentials`

**Credentials**

In order of precedence:

-   `credentials: <filepath>` in the inventory or config file
-   `credential_process: <command>` in the inventory or config file
-   `aws_access_key_id` and `aws_secret_access_key` in the inventory or config file
-   `ENV['AWS_ACCESS_KEY_ID']` and `ENV['AWS_SECRET_ACCESS_KEY']`
-   `~/.aws/credentials`

If the region or credentials are located in a shared credentials file, a `profile` can be specified in the inventory file to choose which set of credentials to use. For example, if the inventory file were set to `profile: user1`, the second set of credentials would be used:

```
[default]
aws_access_key_id=...
aws_secret_access_key=...
region=...

[user1]
aws_access_key_id=...
aws_secret_access_key=...
region=...
```

AWS credential files stored in a non-standard location (`~/.aws/credentials`) can be configured in Bolt:

```
plugins:
  aws:
    credentials: ~/alternate_path/credentials
```

**External Credentials Process**

The `credential_process` supports more complex authentication methods such as SSO or IAM multi-factor authentication.

The `credential_process` parameter expects a command that acquires AWS session credentials from an external process, as documented in [https://docs.aws.amazon.com/cli/latest/topic/config-vars.html#sourcing-credentials-from-external-processes].

**Note:** This example assumes you are running `bolt` in an interactive CLI session and can provide an MFA key to the AWS CLI when prompted.

This profile sets `role_arn` and `mfa_serial` to assume a role that requires MFA authentication. Successful authentication requires presenting a time-based MFA token along with the account credentials.

```
[profile user1-with-mfa-role]
region=...
aws_access_key_id=...
aws_secret_key=...
role_arn = arn:aws:iam::0123456789012:role/user1-role
mfa_serial=arn:aws:iam::0123456789012:mfa/user1
```

Set `credential_process` to run `aws configure export-credentials` from the desired profile:

```
aws_inventory:
  ...
  credential_process: /usr/local/bin/aws configure export-credentials --profile user1-with-mfa-role
```
When the inventory plugin runs, the AWS CLI interactively prompts the user for the MFA token code as needed.

**Note:** The `aws configure export-credentials` feature is only available in AWS CLI version 2.9.0 or later.

### Examples

`inventory.yaml`
```yaml
groups:
  - name: aws
    targets:
      - _plugin: aws_inventory
        profile: user1
        # Example of an external credentials process for profile "user1"
        #credential_process: /usr/local/bin/aws configure export-credentials --profile user1
        region: us-west-1
        filters:
          - name: tag:Owner
            values: [Devs]
          - name: instance-type
            values: [t2.micro, c5.large]
        target_mapping:
          name: public_dns_name
          uri: public_ip_address
          config:
            ssh:
              host: public_dns_name
              user: tag.User
    config:
      ssh:
        user: ec2-user
        private-key: ~/.aws/private-key.pem
        host-key-check: false
```
