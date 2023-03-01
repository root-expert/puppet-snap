# frozen_string_literal: true

require 'spec_helper'

describe 'snap' do
  on_supported_os.each do |os, facts|
    context "on #{os} with snapd running" do
      let(:facts) do
        facts
      end

      it { is_expected.to compile.with_all_deps }

      it { is_expected.to contain_file('/snap').with_ensure('link').with_target('/var/lib/snapd/snap').that_requires('Package[snapd]') } if facts[:osfamily] == 'RedHat'

      it { is_expected.to contain_package('snapd').with_ensure('installed') }
      it { is_expected.to contain_service('snapd').with_ensure('running').with_enable(true).that_requires('Package[snapd]') }
      it { is_expected.to contain_package('net_http_unix').with_ensure('installed').with_provider('puppet_gem').that_requires('Service[snapd]') }
      it { is_expected.to contain_package('core').with_ensure('installed').with_provider('snap').that_requires(%w[Service[snapd] Package[net_http_unix]]) }
    end

    context "on #{os} with snapd stopped" do
      let(:facts) do
        facts
      end

      let(:params) do
        { 'service_ensure' => 'stopped' }
      end

      it { is_expected.to compile.with_all_deps }

      it { is_expected.to contain_package('snapd').with_ensure('installed') }
      it { is_expected.to contain_service('snapd').with_ensure('stopped').with_enable(true).that_requires('Package[snapd]') }
      it { is_expected.to contain_package('net_http_unix').with_ensure('installed').with_provider('puppet_gem').that_requires('Service[snapd]') }
      it { is_expected.not_to contain_package('core').with_provider('snap') }
    end
  end
end
