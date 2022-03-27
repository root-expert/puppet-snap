# frozen_string_literal: true

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

  context 'package resource' do
    describe 'installs package' do
      let(:manifest) do
        <<-PUPPET
          package { 'hello-world':
            ensure   => installed,
            provider => snap,
          }
        PUPPET
      end

      it_behaves_like 'an idempotent resource'

      describe command('snap list --unicode=never --color=never') do
        its(:stdout) { is_expected.to match(%r{hello-world}) }
      end
    end

    describe 'uninstalls package' do
      let(:manifest) do
        <<-PUPPET
          package { 'hello-world':
            ensure   => absent,
            provider => snap,
          }
        PUPPET
      end

      it_behaves_like 'an idempotent resource'

      describe command('snap list --unicode=never --color=never') do
        its(:stdout) { is_expected.not_to match(%r{hello-world}) }
      end
    end

    describe 'installs package with specified version' do
      let(:manifest) do
        <<-PUPPET
          package { 'hello-world':
            ensure   => 'latest/candidate',
            provider => snap,
          }
        PUPPET
      end

      it_behaves_like 'an idempotent resource'

      describe command('snap list --unicode=never --color=never') do
        its(:stdout) do
          is_expected.to match(%r{hello-world})
          is_expected.to match(%r{candidate})
        end
      end
    end

    describe 'changes installed channel' do
      let(:manifest) do
        <<-PUPPET
          package { 'hello-world':
            ensure   => 'latest/beta',
            provider => snap,
          }
        PUPPET
      end

      it_behaves_like 'an idempotent resource'

      describe command('snap list --unicode=never --color=never') do
        its(:stdout) do
          is_expected.to match(%r{hello-world})
          is_expected.to match(%r{beta})
        end
      end
    end
  end
end
