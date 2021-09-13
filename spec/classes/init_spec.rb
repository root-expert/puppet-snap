require 'spec_helper'

describe 'snap' do
  on_supported_os.each do |os, facts|
    context "on #{os}" do
      let(:facts) do
        facts
      end

      it { is_expected.to compile.with_all_deps }

      if facts[:osfamily] == 'RedHat'
        it { is_expected.to contain_class('epel') }
        it { is_expected.to contain_package('snapd').with_ensure('installed').that_requires('Class[epel]') }
        it { is_expected.to contain_file('/snap').with_ensure('link').with_target('/var/lib/snapd/snap').that_requires('Package[snapd]') }
      else
        it { is_expected.to contain_package('snapd').with_ensure('installed') }
        it { is_expected.to contain_service('snapd').with_ensure('running').with_enable(true).that_requires('Package[snapd]') }
        it { is_expected.to contain_package('core').with_ensure('installed').with_provider('snap').that_requires('Service[snapd]') }
      end
    end
  end
end
