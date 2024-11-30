# @summary This class installs snapd and core snap.

# @param package_ensure The state of the snapd package.
# @param service_ensure The state of the snapd service.
# @param service_enable Run the system service on boot.
# @param core_snap_ensure The state of the snap `core`.
# @param manage_repo Whether we should manage EPEL repo or not.
class snap (
  String[1]                              $package_ensure       = 'installed',
  Enum['stopped', 'running']             $service_ensure       = 'running',
  Boolean                                $service_enable       = true,
  String[1]                              $core_snap_ensure     = 'installed',
  Boolean                                $manage_repo          = false,
) {
  if $manage_repo {
    include epel
    Yumrepo['epel'] -> Package['snapd']
  }

  package { 'snapd':
    ensure => $package_ensure,
  }

  if $facts['os']['family'] == 'RedHat' {
    file { '/snap':
      ensure  => link,
      target  => '/var/lib/snapd/snap',
      require => Package['snapd'],
    }
  }

  service { 'snapd':
    ensure  => $service_ensure,
    enable  => $service_enable,
    require => Package['snapd'],
  }

  if $service_ensure == 'running' {
    package { 'core':
      ensure   => $core_snap_ensure,
      provider => 'snap',
      require  => Service['snapd'],
    }
  }
}
