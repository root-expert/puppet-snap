# frozen_string_literal: true

require 'puppet_x/snap/api'

Puppet::Type.type(:snap_conf).provide(:snap_conf) do
  desc 'Manage snap configuration both system wide and snap specific.'

  confine feature: %i[net_http_unix_lib snapd_socket]

  def create
    save_conf
  end

  def destroy
    save_conf
  end

  def exists?
    params = URI.encode_www_form(keys: @resource[:conf])
    res = PuppetX::Snap::API.get("/v2/snaps/#{@resource[:snap]}/conf?#{params}")

    case res['status-code']
    when 200
      # If we reached here the resource exists. If ensure == absent then return true in order to remove it
      true if res['result'][@resource[:conf]] == @resource[:value] || @resource[:ensure] == :absent
    when 400
      return false if res['result']['kind'] == 'option-not-found'

      raise Puppet::Error, "Error while executing the request #{res}"
    else
      raise Puppet::Error, "Error while executing the request #{res}"
    end
  end

  def save_conf
    value = if @resource[:ensure] == :absent
              nil
            else
              @resource[:value]
            end

    data = {
      @resource[:conf] => value
    }

    res = PuppetX::Snap::API.put("/v2/snaps/#{@resource[:snap]}/conf", data)
    change_id = PuppetX::Snap::API.get_id_from_async_req(res)
    PuppetX::Snap::API.complete(change_id)
  end

  def snap
    @resource[:snap]
  end

  def snap=(value)
    @resource[:snap] = value
    save_conf
  end

  def conf
    @resource[:conf]
  end

  def conf=(value)
    @resource[:conf] = value
    save_conf
  end

  def value
    params = URI.encode_www_form(keys: @resource[:conf])
    res = PuppetX::Snap::API.get("/v2/snaps/#{@resource[:snap]}/conf?#{params}")

    case res['status-code']
    when 200
      res['result'][@resource[:conf]]
    when 400
      return nil if res['result']['kind'] == 'option-not-found'

      raise Puppet::Error, "Error while executing the request #{res}"
    else
      raise Puppet::Error, "Error while executing the request #{res}"
    end
  end

  def value=(value)
    @resource[:value] = value
    save_conf
  end
end
