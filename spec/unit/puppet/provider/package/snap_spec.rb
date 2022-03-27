# frozen_string_literal: true

require 'spec_helper'
require 'puppet_x/snap/api'

describe Puppet::Type.type(:package).provider(:snap) do
  let(:name) { 'hello-world' }

  let(:resource) do
    Puppet::Type.type(:package).new(
      name: name,
      provider: 'snap'
    )
  end

  let(:provider) do
    resource.provider
  end

  find_res = JSON.parse(File.read('spec/fixtures/responses/find_res.json'))

  context 'should have provider features' do
    it { is_expected.to be_installable }
    it { is_expected.to be_install_options }
    it { is_expected.to be_uninstallable }
    it { is_expected.to be_purgeable }
  end

  context 'should respond to' do
    it 'install' do
      expect(provider).to respond_to(:install)
    end

    it 'update' do
      expect(provider).to respond_to(:update)
    end

    it 'uninstall' do
      expect(provider).to respond_to(:uninstall)
    end

    it 'purge' do
      expect(provider).to respond_to(:purge)
    end
  end

  context 'installing without any option' do
    it 'generates correct request' do
      response = provider.class.generate_request('install', nil)
      expect(response).to eq('action' => 'install')
    end
  end

  context 'installing with channel option' do
    it 'generates correct request' do
      response = provider.class.generate_request('install', ['channel=beta'])
      expect(response).to eq('action' => 'install', 'channel' => 'beta')
    end
  end

  context 'installing with classic option' do
    it 'generates correct request' do
      response = provider.class.generate_request('install', ['classic'])
      expect(response).to eq('action' => 'install', 'classic' => true)
    end
  end

  context 'querying for latest version' do
    before do
      allow(PuppetX::Snap::API).to receive(:get).with('/v2/find?name=hello-world').and_return(find_res)
    end

    it 'with no channel specified returns correct version from latest/stable channel' do
      expect(provider.latest).to eq('6.4')
    end

    it 'with channel specified returns correct version from specified channel' do
      resource[:install_options] = ['channel=latest/beta']

      expect(provider.latest).to eq('6.0')
    end

    it 'with non-existent channel' do
      resource[:install_options] = ['channel=latest/kokolala']

      expect { provider.latest }.to raise_error(%r{No version in channel latest/kokolala$})
    end
  end
end
