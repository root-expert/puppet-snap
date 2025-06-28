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

    describe 'holds the package (prevents refresh)' do
      let(:manifest) do
        <<-PUPPET
          package { 'hello-world':
            ensure    => 'latest/beta',
            mark      => 'hold',
            provider  => 'snap',
          }
        PUPPET
      end

      it_behaves_like 'an idempotent resource'

      describe command('snap info --unicode=never --color=never --abs-time hello-world') do
        its(:stdout) do
          is_expected.to match(%r{name:\s+hello-world})
          is_expected.to match(%r{tracking:\s+latest/beta})
          is_expected.to match(%r{hold:\s+forever})
        end
      end
    end

    describe 'can change channel while held' do
      let(:manifest) do
        <<-PUPPET
          package { 'hello-world':
            ensure    => 'latest/candidate',
            mark      => 'hold',
            provider  => 'snap',
          }
        PUPPET
      end

      it_behaves_like 'an idempotent resource'

      describe command('snap info --unicode=never --color=never --abs-time hello-world') do
        its(:stdout) do
          is_expected.to match(%r{name:\s+hello-world})
          is_expected.to match(%r{tracking:\s+latest/candidate})
          is_expected.to match(%r{hold:\s+forever})
        end
      end
    end

    describe 'hold until specified date' do
      let(:manifest) do
        <<-PUPPET
          package { 'hello-world':
            ensure          => 'latest/candidate',
            mark            => 'hold',
            install_options => 'hold_time=2025-10-10', # Non RFC3339, it should be parsed correctly
            provider        => 'snap',
          }
        PUPPET
      end

      it_behaves_like 'an idempotent resource'

      describe command('snap info --unicode=never --color=never --abs-time hello-world') do
        its(:stdout) do
          is_expected.to match(%r{name:\s+hello-world})
          is_expected.to match(%r{tracking:\s+latest/candidate})
          is_expected.to match(%r{hold:\s+2025-10-10T03:00:00})
        end
      end
    end

    describe 'unholds the package' do
      let(:manifest) do
        <<-PUPPET
          package { 'hello-world':
            ensure    => 'latest/candidate',
            provider  => 'snap',
          }
        PUPPET
      end

      it_behaves_like 'an idempotent resource'

      describe command('snap info --unicode=never --color=never --abs-time hello-world') do
        its(:stdout) do
          is_expected.to match(%r{name:\s+hello-world})
          is_expected.to match(%r{tracking:\s+latest/candidate})
          is_expected.not_to match(%r{hold:.*})
        end
      end
    end

    describe 'purges the package' do
      let(:manifest) do
        <<-PUPPET
          package { 'hello-world':
            ensure   => purged,
            provider => snap,
          }
        PUPPET
      end

      it_behaves_like 'an idempotent resource'

      describe command('snap list --unicode=never --color=never') do
        its(:stdout) { is_expected.not_to match(%r{hello-world}) }
      end
    end

    # rubocop:disable RSpec/EmptyExampleGroup
    describe 'Raises error when ensure => latest' do
      manifest = <<-PUPPET
          package { 'hello-world':
            ensure   => latest,
            provider => snap,
          }
      PUPPET

      apply_manifest(manifest, expect_failures: true)
    end
    # rubocop:enable RSpec/EmptyExampleGroup
  end
end
