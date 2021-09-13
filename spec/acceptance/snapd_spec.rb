require 'spec_helper_acceptance'

describe 'snapd class' do
  context 'with default parameters' do
    let(:manifest) { "class {'snap': }" }

    it_behaves_like 'an idempotent resource'

    describe package('snapd') do
      it { is_expected.to be_installed }
    end

    describe service('snapd') do
      it { is_expected.to be_running }
      it { is_expected.to be_enabled }
    end

    describe file('/run/snapd.socket') do
      it { is_expected.to be_socket }
    end
  end
end
