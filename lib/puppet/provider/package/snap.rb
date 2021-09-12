require 'puppet/provider/package'
require 'socket'
require 'json'

Puppet::Type.type(:package).provide :snap, parent: Puppet::Provider::Package do
  desc "Package management via Snap.

    This provider supports the `install_options` attribute, which allows snap's flags to be
    passed to Snap. Namely `classic`, `dangerous`, `devmode`, `jailmode`, `channel`.

    This provider supports the `uninstall_options` attribute, which allows snap's flags to be
    passed to Snap. Namely `purge`."

  has_feature :install_options
  has_feature :uninstall_options

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

  def uninstall
    self.class.modify_snap('remove', @resource[:name], @resource[:uninstall_options])
  end

  def purge
    uninstall
  end

  def self.call_api(method, url, data = nil)
    request = "#{method} #{url} HTTP/1.1\r\n" \
"Host: localhost\r\n" \
"Accept: application/json\r\n" \
"Content-Type: application/json\r\n"

    if method == 'POST'
      post_data = data.to_json.to_s
      # Add Content-Length Header since we have some payload
      request << "Content-Length: #{post_data.bytesize}\r\n\r\n#{post_data}"
    end
    # HTTP headers should end with blank line
    request << "\r\n"

    res = nil
    UNIXSocket.open('/run/snapd.socket') do |socket|
      socket.write(request)
      reply = socket.recv(8192)

      # Strip HTTP headers
      res = reply.split(%r{\r\n\r\n})[1]
    end

    raise Puppet::Error, 'There was an error calling Snap API' if res.nil?
    JSON.parse(res)
  end

  def self.installed_snaps
    res = call_api('GET', '/v2/snaps')

    unless [200, 404].include?(res['status-code'])
      raise Puppet::Error, format('Could not find installed snaps (code: %s)', res['status-code'])
    end

    res['result'].map { |hash| hash.slice('name', 'version') } if res['status-code'] == 200
  end

  # Helper method to return the change ID from a asynchronous request response.
  def self.get_id_from_async_req(request)
    # If the request failed raise an error
    if request['type'] == 'error'
      raise Puppet::Error, format('Request failed with %s', request['result']['message'])
    end

    request['change']
  end

  # Get the status of a change
  #
  # @param id The change ID to search for.
  def self.get_status(id)
    call_api('GET', "/v2/changes/#{id}")
  end

  # Queries the API for a specific change and waits until it has
  # been completed.
  #
  # @param id The change ID to search for.
  def self.complete(id)
    completed = false
    until completed
      res = get_status(id)
      case res['result']['status']
      when 'Do', 'Doing', 'Undoing', 'Undo'
        # Still running
        next
      when 'Abort', 'Hold', 'Error'
        raise Puppet::Error, format('Error while executing the request %s', res)
      when 'Done'
        completed = true
      else
        raise Puppet::Error, format('Unknown status %s', res)
      end

      # Wait a little bit before hitting the API again!
      sleep(1)
    end
  end

  def self.generate_request(action, options)
    request = { 'action' => action }

    if options
      channel = options['channel']
      if channel && channel != 'stable' && %w[install refresh].include?(action)
        request['channel'] = options['channel']
      end

      # classic, devmode and jailmode params are only available for istall, refresh, revert actions.
      if %w[install refresh revert].include?(action)
        request['classic'] = options['classic'] if options['classic']
        request['devmode'] = options['devmode'] if options['devmode']
        request['jailmode'] = options['jailmode'] if options['jailmode']
      end
    end

    request
  end

  def self.modify_snap(action, name, options)
    req = generate_request(action, options)
    response = call_api('POST', "/v2/snaps/#{name}", req)
    change_id = get_id_from_async_req(response)
    complete(change_id)
  end
end
