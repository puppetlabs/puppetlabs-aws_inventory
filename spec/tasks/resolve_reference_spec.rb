# frozen_string_literal: true

require 'spec_helper'
require_relative '../../tasks/resolve_reference.rb'

describe AwsInventory do
  let(:ip1) { '255.255.255.255' }
  let(:ip2) { '127.0.0.1' }
  let(:name1) { 'test-instance-1' }
  let(:name2) { 'test-instance-2' }
  let(:test_instances) {
    [
      { instance_id: name1,
        public_ip_address: ip1,
        public_dns_name: name1,
        state: { name: 'running' } },
      { instance_id: name2,
        public_ip_address: ip2,
        public_dns_name: name2,
        state: { name: 'running' } }
    ]
  }

  let(:test_client) {
    ::Aws::EC2::Client.new(
      stub_responses: { describe_instances: { reservations: [{ instances: test_instances }] } }
    )
  }

  let(:opts) do
    {
      filters: [{ name: 'tag:Owner', values: ['foo'] }],
      target_mapping: {
        name: 'public_dns_name',
        uri: 'public_ip_address'
      }
    }
  end

  def deep_merge(hash1, hash2)
    recursive_merge = proc do |_key, h1, h2|
      if h1.is_a?(Hash) && h2.is_a?(Hash)
        h1.merge(h2, &recursive_merge)
      else
        h2
      end
    end
    hash1.merge(hash2, &recursive_merge)
  end

  context "with fake client" do
    before(:each) do
      subject.client = test_client
    end

    describe "#resolve_reference" do
      it 'matches all running instances' do
        targets = subject.resolve_reference(opts)
        expect(targets).to contain_exactly({ name: name1, uri: ip1 },
                                           name: name2, uri: ip2)
      end

      it 'sets only name if uri is not specified' do
        opts[:target_mapping].delete(:uri)
        targets = subject.resolve_reference(opts)
        expect(targets).to contain_exactly({ name: name1 },
                                           name: name2)
      end

      it 'builds a config map from the inventory' do
        config_template = { target_mapping: { config: { ssh: { host: 'public_ip_address' } } } }
        targets = subject.resolve_reference(deep_merge(opts, config_template))

        config1 = { ssh: { host: ip1 } }
        config2 = { ssh: { host: ip2 } }
        expect(targets).to contain_exactly({ name: name1, uri: ip1, config: config1 },
                                           name: name2, uri: ip2, config: config2)
      end

      it 'raises an error if name or uri are not templated' do
        expect { subject.resolve_reference(opts.delete(:target_mapping)) }
          .to raise_error(/You must provide a 'name' or 'uri'/)
      end
    end
  end

  describe "#config_client" do
    it 'raises a validation error when credentials file path does not exist' do
      config_data = { credentials: 'credentials', _boltdir: 'who/are/you' }
      expect { subject.config_client(opts.merge(config_data)) }
        .to raise_error(%r{who/are/you/credentials})
    end
  end

  describe "#task" do
    it 'returns the list of targets' do
      targets = [
        { "uri": "1.2.3.4", "name": "my-instance" },
        { "uri": "1.2.3.5", "name": "my-other-instance" }
      ]
      allow(subject).to receive(:resolve_reference).and_return(targets)

      result = subject.task(opts)
      expect(result).to have_key(:value)
      expect(result[:value]).to eq(targets)
    end
  end
end
