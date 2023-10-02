# frozen_string_literal: true

# Managed by modulesync - DO NOT EDIT
# https://voxpupuli.org/docs/updating-files-managed-with-modulesync/

require 'voxpupuli/acceptance/spec_helper_acceptance'

configure_beaker do |host|
  # Snap uses udev, so install it and enable it before installing snap.
  pp = <<-PUPPET
    package { 'udev':
      ensure => installed,
    }

    service { 'systemd-udevd':
      ensure  => 'running',
      enable  => true,
      require => Package['udev'],
    }
  PUPPET

  debian = <<-PUPPET
    package { ['fuse', 'squashfuse']:
      ensure => installed,
    }
  PUPPET

  apply_manifest_on(host, pp, catch_failures: true)
  apply_manifest_on(host, debian, catch_failures: true) if fact('os.family') == 'Debian'
  install_puppet_module_via_pmt_on(host, 'puppet/epel') if fact('os.family') == 'RedHat'
end

Dir['./spec/support/acceptance/**/*.rb'].sort.each { |f| require f }
