require 'spec_helper'

describe ShipmentTracking::UPS do

  describe 'track' do

    let (:auth_options) {
      {
          #Fill this in to make it work
          # username: ,
          # password: ,
          # access_key:
      }
    }

    context 'a real tracking code' do

      # This is subject to change!
      let(:tracking_code) { '1Z7253RV2011114369' }

      it 'works' do
        shipment = described_class.track(tracking_code, auth_options)
        expect(shipment.lookup_succeeded).to be_truthy
        expect(shipment.expected_delivery_date).to be_an_instance_of(Date)
        expect(shipment.history.empty?).to be_falsey
      end
    end

    context 'a non-existent tracking code' do

      let(:tracking_code) { 'ABC123' }

      it 'returns a failure code' do
        shipment = described_class.track(tracking_code, auth_options)
        expect(shipment.lookup_succeeded).to be_falsey
      end
    end


  end
end