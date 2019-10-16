#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../../ruby_task_helper/files/task_helper.rb'
require 'json'
require 'aws-sdk-ec2'

class AwsInventory < TaskHelper
  attr_accessor :client

  def config_client(opts)
    return client if client

    options = {}

    if opts.key?(:region)
      options[:region] = opts[:region]
    end
    if opts.key?(:profile)
      options[:profile] = opts[:profile]
    end
    if opts[:credentials]
      creds = File.expand_path(opts[:credentials])
      if File.exist?(creds)
        options[:credentials] = Aws::SharedCredentials.new(path: creds)
      else
        msg = "Cannot load credentials file #{opts[:credentials]}"
        raise TaskHelper::Error.new(msg, 'bolt-plugin/validation-error')
      end
    end

    Aws::EC2::Client.new(options)
  end

  def resolve_reference(opts)
    client = config_client(opts)
    resource = Aws::EC2::Resource.new(client: client)

    # Retrieve a list of EC2 instances and create a list of targets
    # Note: It doesn't seem possible to filter stubbed responses...
    resource.instances(filters: opts[:filters]).map do |instance|
      next unless instance.state.name == 'running'
      target = {}

      if opts.key?(:uri)
        uri = lookup(instance, opts[:uri])
        target['uri'] = uri if uri
      end
      if opts.key?(:name)
        real_name = lookup(instance, opts[:name])
        target['name'] = real_name if real_name
      end
      if opts.key?(:config)
        target['config'] = resolve_config(instance, opts[:config])
      end

      target if target['uri'] || target['name']
    end.compact
  end

  # Look for an instance attribute specified in the inventory file
  def lookup(instance, attribute)
    instance.data.respond_to?(attribute) ? instance.data[attribute] : nil
  end

  # Walk the "template" config mapping provided in the plugin config and
  # replace all values with the corresponding value from the resource
  # parameters.
  def resolve_config(name, config_template)
    walk_vals(config_template) do |value|
      if value.is_a?(String)
        lookup(name, value)
      else
        value
      end
    end
  end

  # Accepts a Data object and returns a copy with all hash and array values
  # Arrays and hashes including the initial object are modified before
  # their descendants are.
  def walk_vals(data, skip_top = false, &block)
    data = yield(data) unless skip_top
    if data.is_a? Hash
      map_vals(data) { |v| walk_vals(v, &block) }
    elsif data.is_a? Array
      data.map { |v| walk_vals(v, &block) }
    else
      data
    end
  end

  def map_vals(hash)
    hash.each_with_object({}) do |(k, v), acc|
      acc[k] = yield(v)
    end
  end

  def task(opts)
    targets = resolve_reference(opts)
    return { value: targets }
  rescue TaskHelper::Error => e
    # ruby_task_helper doesn't print errors under the _error key, so we have to
    # handle that ourselves
    return { _error: e.to_h }
  end
end

AwsInventory.run if $PROGRAM_NAME == __FILE__
