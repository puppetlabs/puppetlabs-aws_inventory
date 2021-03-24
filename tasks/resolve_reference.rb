#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../../ruby_task_helper/files/task_helper.rb'
require_relative '../../ruby_plugin_helper/lib/plugin_helper.rb'
require 'json'
require 'aws-sdk-ec2'

class AwsInventory < TaskHelper
  include RubyPluginHelper

  attr_accessor :client

  def client_config(opts)
    config = {}

    if opts.key?(:region)
      config[:region] = opts[:region]
    end
    if opts.key?(:profile)
      config[:profile] = opts[:profile]
    end
    if opts[:credentials]
      creds = File.expand_path(opts[:credentials], opts[:_boltdir])
      if File.exist?(creds)
        config[:credentials] = Aws::SharedCredentials.new(path: creds)
      else
        msg = "Cannot load credentials file #{creds}"
        raise TaskHelper::Error.new(msg, 'bolt-plugin/validation-error')
      end
    else
      if opts.key?(:aws_access_key_id)
        config[:access_key_id] = opts[:aws_access_key_id]
      end
      if opts.key?(:aws_secret_access_key)
        config[:secret_access_key] = opts[:aws_secret_access_key]
      end
    end

    config
  end

  def build_client(opts)
    return client if client

    config = client_config(opts)
    Aws::EC2::Client.new(config)
  end

  def resolve_reference(opts)
    template = opts.delete(:target_mapping) || {}
    unless template.key?(:uri) || template.key?(:name)
      msg = "You must provide a 'name' or 'uri' in 'target_mapping' for the AWS plugin"
      raise TaskHelper::Error.new(msg, 'bolt-plugin/validation-error')
    end

    client = build_client(opts)
    resource = Aws::EC2::Resource.new(client: client)

    # Retrieve a list of EC2 instances and create a list of targets
    # Note: It doesn't seem possible to filter stubbed responses...
    targets = resource.instances(filters: opts[:filters]).select { |i| i.state.name == 'running' }

    attributes = required_data(template)
    target_data = targets.map do |target|
      attributes.each_with_object({}) do |attr, acc|
        attr = attr.first
        acc[attr] = target.respond_to?(attr) ? target.send(attr) : nil
      end
    end

    # "tags" is a special case where we want to transform the array-of-maps
    # structure returned from the API into a single key/value map so that
    # tags can be referenced in a template
    target_data.each do |target|
      next unless target['tags']

      tag_map = target['tags'].each_with_object({}) do |tag, tags|
        tags[tag['key']] = tag['value']
      end
      target['tags'] = tag_map
    end

    target_data.map { |data| apply_mapping(template, data) }
  end

  def task(opts = {})
    targets = resolve_reference(opts)
    { value: targets }
  end
end

AwsInventory.run if $PROGRAM_NAME == __FILE__
