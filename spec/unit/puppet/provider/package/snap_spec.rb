require 'spec_helper'

describe Puppet::Type.type(:package).provider(:snap) do
  let(:name) { 'test' }

  let(:resource) do
    Puppet::Type.type(:package).new(
      name: name,
      provider: 'snap'
    )
  end

  let(:provider) do
    resource.provider
  end

  context 'should have provider features' do
    it { is_expected.to be_install_options }
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
end
