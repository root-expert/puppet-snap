require 'spec_helper'

describe Puppet::Type.type(:package).provider(:snap) do
  let(:name) { 'test' }

  let(:resource) do
    Puppet::Type.type(:package).new(
      :name => name,
      :provider => 'snap'
    )
  end

  let(:provider) do
    resource.provider
  end

  context 'should have provider features' do
    it { is_expected.to be_install_options }
    it { is_expected.to be_uninstall_options }
  end
end
