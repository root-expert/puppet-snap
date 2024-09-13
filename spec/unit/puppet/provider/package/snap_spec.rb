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

  before do
    allow(PuppetX::Snap::API).to receive(:get).with('/v2/snaps').and_return('[]')
  end

  context 'should have provider features' do
    it { is_expected.to be_installable }
    it { is_expected.to be_versionable }
    it { is_expected.to be_install_options }
    it { is_expected.to be_uninstallable }
    it { is_expected.to be_purgeable }
    it { is_expected.to be_upgradeable }
    it { is_expected.to be_holdable }
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
      response = provider.class.generate_request('install', nil, nil)
      expect(response).to eq('action' => 'install')
    end
  end

  context 'installing with channel' do
    it 'generates correct request' do
      response = provider.class.generate_request('install', 'beta', nil)
      expect(response).to eq('action' => 'install', 'channel' => 'beta')
    end
  end

  context 'installing with classic option' do
    it 'generates correct request' do
      response = provider.class.generate_request('install', nil, ['classic'])
      expect(response).to eq('action' => 'install', 'classic' => true)
    end
  end

  context 'decides the correct channel usage' do
    it 'with no channel specified returns correct ensure value' do
      expect(provider.determine_channel).to eq('latest/stable')
    end

    it 'with channel specified in ensure returns correct ensure value' do
      resource[:ensure] = 'latest/beta'

      expect(provider.determine_channel).to eq('latest/beta')
    end

    it 'with channel specified in install options returns correct ensure value' do
      resource[:install_options] = ['channel=latest/beta']

      expect(provider.determine_channel).to eq('latest/beta')
    end

    it 'with channel specified in both ensure install options returns correct ensure value' do
      resource[:install_options] = ['channel=latest/beta']
      resource[:ensure] = 'latest/candidate' # this should be preferred

      expect(provider.determine_channel).to eq('latest/candidate')
    end
  end
end
