# frozen_string_literal: true

require 'spec_helper'
require 'puppet_x/snap/api'

describe Puppet::Type.type(:snap_conf) do
  let(:name) { 'hello-world' }
  let(:resource) do
    Puppet::Type.type(:snap_conf).new(
      name: name,
      snap: 'system',
      conf: 'refresh.retain',
      value: '3'
    )
  end
  let(:provider) do
    resource.provider
  end

  it 'defaults to ensure => present' do
    expect(resource[:ensure]).to eq :present
  end
end
