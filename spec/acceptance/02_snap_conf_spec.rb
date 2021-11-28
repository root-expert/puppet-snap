# frozen_string_literal: true

require 'spec_helper_acceptance'

describe 'snap_conf resource' do
  context 'snap_conf' do
    let(:manifest) do
      <<-EOS
      snap_conf { 'test1':
        ensure => present,
        snap   => 'system',
        conf   => 'refresh.retain',
        value  => '3'
      }
      EOS
    end

    it_behaves_like 'an idempotent resource'

    describe command('snap get system refresh.retain') do
      its(:stdout) { is_expected.to match %r{3} }
    end
  end

  context 'destroy resource' do
    let(:manifest) do
      <<-EOS
      snap_conf { 'test1':
        ensure => absent,
        snap   => 'system',
        conf   => 'refresh.retain',
      }
      EOS
    end

    it_behaves_like 'an idempotent resource'

    describe command('snap get system refresh.retain') do
      its(:stderr) { is_expected.to match %r{error: snap "core" has no "refresh.retain" configuration option} }
    end
  end
end
