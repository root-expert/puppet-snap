require 'puppet/provider/package'
require 'socket'
require 'json'

Puppet::Type.type(:package).provide :snap, :parent => Puppet::Provider::Package do
  desc "Package management via Snap.

    This provider supports the `install_options` attribute, which allows snap's flags to be
    passed to Snap. Namely `classic`, `dangerous`, `devmode`, `jailmode`, `channel`.

    This provider supports the `uninstall_options` attribute, which allows snap's flags to be
    passed to Snap. Namely `purge`."

  commands :snap => "/usr/bin/snap"
  has_feature :install_options
  has_feature :uninstall_options

  def self.instances
    installed_snaps
  end

  def install
    modify_snap('install', @resource[:name], @resource[:install_options])
  end

  def update
    modify_snap('refresh', @resource[:name], @resource[:install_options])
  end

  def uninstall
    modify_snap('remove', @resource[:name], @resource[:uninstall_options])
  end

  def purge
    uninstall
  end

  def call_api(method, url, data = nil)
    request = "#{method} #{url} HTTP/1.1\r\n" \
"Accept: application/json\r\n" \
"Content-Type: application/json\r\n"

    if method == 'POST'
      post_data = data.to_json.to_s
      # Add Content-Length Header since we have some payload
      request.concat(request, "Content-Length: #{post_data.bytesize}\r\n\r\n#{post_data}")
    end
    # HTTP headers should end with blank line
    request.concat(request, "\r\n")

    res = nil
    UNIXSocket.open('/run/snapd.socket') do |socket|
      socket.write(request)
      reply = socket.recv

      # Strip HTTP headers
      res = reply.split(%r{\r\n\r\n})[1]
    end

    raise Puppet::Error('There was an error calling Snap API') if res.nil?
    res
  end

  def installed_snaps
    res = call_api('GET', '/v2/snaps/')

    if res['status-code'] != 200
      raise Puppet::Error(format('Could not find installed snaps %s', res['result']))
    end

    res.map { |snap| snap.is_a?(Hash) ? snap['name'] : next }
  end

  # Helper method to return the change ID from a asynchronous request response.
  def get_id_from_async_req(request)
    # If the request failed raise an error
    if request['type'] == 'error'
      raise Puppet::Error(format('Request failed with %s', request['result']['message']))
    end

    request['change']
  end

  # Get the status of a change
  #
  # @param id The change ID to search for.
  def get_status(id)
    call_api('GET', "/v2/changes/#{id}")
  end

  # Queries the API for a specific change and waits until it has
  # been completed.
  #
  # @param id The change ID to search for.
  def complete(id)
    completed = false
    until completed
      res = get_status(id)
      case res['result']['status']
      when 'Do', 'Doing', 'Undoing', 'Undo'
        # Still running
        next
      when 'Abort', 'Hold', 'Error'
        raise Puppet::Error(format('Error while executing the request %s', res))
      when 'Done'
        completed = true
      else
        raise Puppet::Error(format('Unknown status %s', res))
      end

      # Wait a little bit before hitting the API again!
      sleep(1)
    end
  end

  def generate_request(action, options)
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

  def modify_snap(action, name, options)
    req = generate_request(action, options)
    response = call_api('POST', "/v2/snaps/#{name}", req)
    change_id = get_id_from_async_req(response)
    complete(change_id)
  end
end
