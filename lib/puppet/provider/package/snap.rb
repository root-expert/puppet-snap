# frozen_string_literal: true

require 'puppet/provider/package'
require 'puppet_x/snap/api'

Puppet::Type.type(:package).provide :snap, parent: Puppet::Provider::Package do
  desc "Package management via Snap.

    This provider supports the `install_options` attribute, which allows snap's flags to be
    passed to Snap. Namely `classic`, `dangerous`, `devmode`, `jailmode`, `channel`."

  commands snap_cmd: '/usr/bin/snap'
  has_feature :installable, :install_options, :uninstallable, :purgeable
  confine feature: %i[net_http_unix_lib snapd_socket]

  def self.instances
    instances = []
    snaps = installed_snaps

    snaps.each do |snap|
      instances << new(name: snap['name'], ensure: snap['version'], provider: 'snap')
    end

    instances
  end

  def query
    instances = self.class.instances
    instances.each do |instance|
      return instance if instance.name == @resource[:name]
    end

    nil
  end

  def install
    self.class.modify_snap('install', @resource[:name], @resource[:install_options])
  end

  def update
    self.class.modify_snap('refresh', @resource[:name], @resource[:install_options])
  end

  def latest
    params = URI.encode_www_form(name: @resource[:name])
    res = PuppetX::Snap::API.get("/v2/find?#{params}")

    raise Puppet::Error, "Couldn't find latest version" if res['status-code'] != 200

    # Search latest version for the specified channel. If channel is unspecified, fallback to latest/stable
    channel = if @resource[:install_options].nil?
                'latest/stable'
              else
                self.class.parse_channel(@resource[:install_options])
              end

    selected_channel = res['result'].first&.dig('channels', channel)
    raise Puppet::Error, "No version in channel #{channel}" unless selected_channel

    # Return version
    selected_channel['version']
  end

  def uninstall
    self.class.modify_snap('remove', @resource[:name])
  end

  # Purge differs from remove as it doesn't save snapshot with snap's data.
  def purge
    self.class.modify_snap('remove', @resource[:name], ['purge'])
  end

  def self.installed_snaps
    res = PuppetX::Snap::API.get('/v2/snaps')

    raise Puppet::Error, "Could not find installed snaps (code: #{res['status-code']})" unless [200, 404].include?(res['status-code'])

    res['result'].map { |hash| hash.slice('name', 'version') } if res['status-code'] == 200
  end

  def self.generate_request(action, options)
    request = { 'action' => action }

    if options
      channel = parse_channel(options)
      request['channel'] = channel unless channel.nil?

      # classic, devmode and jailmode params are only available for install, refresh, revert actions.
      if %w[install refresh revert].include?(action)
        request['classic'] = true if options.include?('classic')
        request['devmode'] = true if options.include?('devmode')
        request['jailmode'] = true if options.include?('jailmode')
      end

      request['purge'] = true if action == 'remove' && options.include?('purge')
    end

    request
  end

  def self.modify_snap(action, name, options = nil)
    req = generate_request(action, options)
    response = PuppetX::Snap::API.post("/v2/snaps/#{name}", req)
    change_id = PuppetX::Snap::API.get_id_from_async_req(response)
    PuppetX::Snap::API.complete(change_id)
  end

  def self.parse_channel(options)
    if (channel = options.find { |e| %r{channel} =~ e })
      return channel.split('=')[1]
    end

    nil
  end
end
