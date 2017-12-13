require 'spec_helper'

describe ShipmentTracking::CanadaPost do

  let (:auth) {
    # This needs to be defined for the tests to work.
    { username: '', password: ''}
  }

  describe 'track' do

    context 'a real tracking code' do

      # This is subject to change!
      let(:tracking_code) { 'EE186834316CA' }

      it 'works' do
        shipment = described_class.track(tracking_code, auth)
        expect(shipment.lookup_succeeded).to be_truthy
        expect(shipment.expected_delivery_date).to be_an_instance_of(Date)
        expect(shipment.history.empty?).to be_falsey
      end

      it 'returns a proper status on http error' do
        expect(RestClient::Request).to receive(:execute).and_raise(RestClient::Exception.new)
        expect(described_class.track(tracking_code, auth).lookup_result).to eq 'No response'
      end
    end

    context 'a non-existent tracking code' do

      let(:tracking_code) { 'EE55555555CA' }

      it 'returns a failure code' do
        shipment = described_class.track(tracking_code, auth)
        expect(shipment.lookup_succeeded).to be_falsey
      end
    end


  end
end