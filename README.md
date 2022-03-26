# puppet-snap

[![Build Status](https://github.com/root-expert/puppet-snap/workflows/CI/badge.svg)](https://github.com/root-expert/puppet-snap/actions?query=workflow%3ACI)
[![Release](https://github.com/root-expert/puppet-snap/actions/workflows/release.yml/badge.svg)](https://github.com/root-expert/puppet-snap/actions/workflows/release.yml)
[![Puppet Forge](https://img.shields.io/puppetforge/v/rootexpert/snap.svg)](https://forge.puppet.com/modules/rootexpert/snap)
[![Puppet Forge - downloads](https://img.shields.io/puppetforge/dt/rootexpert/snap.svg)](https://forge.puppet.com/modules/rootexpert/snap)
[![Puppet Forge - endorsement](https://img.shields.io/puppetforge/e/rootexpert/snap.svg)](https://forge.puppet.com/modules/rootexpert/snap)
[![Puppet Forge - scores](https://img.shields.io/puppetforge/f/rootexpert/snap.svg)](https://forge.puppet.com/modules/rootexpert/snap)
[![puppetmodule.info docs](http://www.puppetmodule.info/images/badge.png)](http://www.puppetmodule.info/m/rootexpert-snap)
[![Apache-2 License](https://img.shields.io/github/license/root-expert/puppet-snap.svg)](LICENSE)

#### Table of Contents

1. [Module Description - What the module does and why it is useful](#module-description)
2. [Setup - The basics of getting started with snap](#setup)
   * [What snap affects](#what-snap-affects)
   * [Setup requirements](#setup-requirements)
   * [Beginning with snap](#beginning-with-snap)
3. [Usage - Configuration options and additional functionality](#usage)
4. [Reference - An under-the-hood peek at what the module is doing and how](#reference)
5. [Limitations - OS compatibility, etc.](#limitations)
6. [Development - Guide for contributing to the module](#development)
7. [License and Author](#license)

## Module Description

This module installs Snap and `core` snap package. Also it provides a package provider, named `snap`, which uses
the [Snapd REST API](https://snapcraft.io/docs/snapd-api) for managing snaps.

## Setup

## What Snap Affects

* the snapd package
* the core snap package
* the snapd daemon

## Beginning with snap

To install Snap and the core package:

```puppet
include snap
```

If you are using a RedHat family OS you need to additionally install [puppet-epel](https://github.com/voxpupuli/puppet-epel)
module or manage the EPEL repository on your own.

If you don't want puppet-snap to manage EPEL:

```puppet
class { 'snap':
  manage_repo => false,
}
```

## Usage

This module also provides a package provider for installing and managing snaps.

To install a snap:

```puppet
package { 'hello-world':
  ensure   => installed,
  provider => 'snap',
}
```

To uninstall a snap:

```puppet
package { 'hello-world':
  ensure   => absent,
  provider => 'snap',
}
```

To purge a snap (_warning purging will remove all snap data_):

```puppet
package { 'hello-world':
  ensure   => purge,
  provider => 'snap',
}
```

To install from specific channel:

```puppet
package { 'hello-world':
  ensure          => installed,
  provider        => 'snap',
  install_options => ['channel=beta'],
}
```

If you want to install a snap in classic mode:

```puppet
package { 'hello-world':
  ensure          => installed,
  provider        => 'snap',
  install_options => ['classic'],
}
```

Same applies for options `jailmode` and `devmode`

## Reference

See [REFERENCE](https://github.com/root-expert/puppet-snap/blob/master/REFERENCE.md)

## Limitations

This module has been tested on the OSes listed
in [metadata.json](https://github.com/root-expert/puppet-snap/blob/master/metadata.json)

## Development

See [CONTRIBUTING](https://github.com/root-expert/puppet-snap/blob/master/.github/CONTRIBUTING.md)

## License and Author

This module was originally written by [Christos Papageorgiou (root-expert)](https://github.com/root-expert). It's licensed
under [Apache 2.0](https://github.com/root-expert/puppet-snap/blob/master/LICENSE).
