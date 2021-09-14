require 'spec_helper'

describe Puppet::Type.type(:package).provider(:snap) do
  let(:name) { 'test' }

  let(:resource) do
    Puppet::Type.type(:package).new(
      name: name,
      provider: 'snap'
    )
  end

  let(:provider) do
    resource.provider
  end

  async_change_id_res = File.read(File.expand_path(File.join(File.dirname(__FILE__), '../../../../fixtures/responses/async_change_id_res.json')))
  error_res = File.read(File.expand_path(File.join(File.dirname(__FILE__), '../../../../fixtures/responses/error_res.json')))
  change_status_doing = File.read(File.expand_path(File.join(File.dirname(__FILE__), '../../../../fixtures/responses/change_status_doing.json')))
  change_status_done = File.read(File.expand_path(File.join(File.dirname(__FILE__), '../../../../fixtures/responses/change_status_done.json')))
  change_status_error = File.read(File.expand_path(File.join(File.dirname(__FILE__), '../../../../fixtures/responses/change_status_error.json')))

  context 'should have provider features' do
    it { is_expected.to be_install_options }
    it { is_expected.to be_purgeable }
  end

  context 'should respond to' do
    it 'install' do
      expect(provider).to respond_to(:install)
    end

    it 'update' do
      expect(provider).to respond_to(:update)
    end

    it 'uninstall' do
      expect(provider).to respond_to(:uninstall)
    end

    it 'purge' do
      expect(provider).to respond_to(:purge)
    end
  end

  context 'installing without any option' do
    it 'generates correct request' do
      response = provider.class.generate_request('install', nil)
      expect(response).to eq('action' => 'install')
    end
  end

  context 'installing with channel option' do
    it 'generates correct request' do
      response = provider.class.generate_request('install', ['--channel=beta'])
      expect(response).to eq('action' => 'install', 'channel' => 'beta')
    end
  end

  context 'installing with classic option' do
    it 'generates correct request' do
      response = provider.class.generate_request('install', ['--classic'])
      expect(response).to eq('action' => 'install', 'classic' => true)
    end
  end

  context 'calling async operations' do
    it 'raises an error if response is an error' do
      expect { provider.class.get_id_from_async_req(JSON.parse(error_res)) }.to raise_error(Puppet::Error)
    end

    it 'gets correct change id from response' do
      id = provider.class.get_id_from_async_req(JSON.parse(async_change_id_res))
      expect(id).to eq('77')
    end
  end

  context 'completing async operations' do
    it 'raises an error if response is an error' do
      allow(described_class).to receive(:get_status).with('10').and_return(JSON.parse(change_status_error))

      expect { provider.class.complete('10') }.to raise_error(Puppet::Error)
    end

    it 'sleeps for 1 second if response hasn\'t completed' do
      allow(described_class).to receive(:get_status).with('10').and_return(JSON.parse(change_status_doing), JSON.parse(change_status_done))
      allow(described_class).to receive(:sleep)
      provider.class.complete('10')

      expect(described_class).to have_received(:sleep).with(1)
    end
  end
end
