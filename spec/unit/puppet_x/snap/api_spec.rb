# frozen_string_literal: true

require 'spec_helper'
require 'puppet_x/snap/api'

module PuppetX::Snap
  describe API do
    async_change_id_res = JSON.parse(File.read('spec/fixtures/responses/async_change_id_res.json'))
    error_res = JSON.parse(File.read('spec/fixtures/responses/error_res.json'))
    change_status_doing = JSON.parse(File.read('spec/fixtures/responses/change_status_doing.json'))
    change_status_done = JSON.parse(File.read('spec/fixtures/responses/change_status_done.json'))
    change_status_error = JSON.parse(File.read('spec/fixtures/responses/change_status_error.json'))

    context 'calling async operations' do
      it 'raises an error if response is an error' do
        expect { described_class.get_id_from_async_req(error_res) }.to raise_error(Puppet::Error)
      end

      it 'gets correct change id from response' do
        id = described_class.get_id_from_async_req(async_change_id_res)
        expect(id).to eq('77')
      end
    end

    context 'completing async operations' do
      it 'raises an error if response is an error' do
        allow(described_class).to receive(:get_status).with('10').and_return(change_status_error)

        expect { described_class.complete('10') }.to raise_error(Puppet::Error)
      end

      it 'sleeps for 1 second if response hasn\'t completed' do
        allow(described_class).to receive(:get_status).with('10').and_return(change_status_doing, change_status_done)
        allow(described_class).to receive(:sleep)
        described_class.complete('10')

        expect(described_class).to have_received(:sleep).with(1)
      end
    end
  end
end
