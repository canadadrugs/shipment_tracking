module ShipmentTracking
  class Shipment
    attr_reader :lookup_succeeded, :lookup_result, :delivery_status, :expected_delivery_date, :history

    def initialize(lookup_succeeded: nil, lookup_result: nil, delivery_status: nil, expected_delivery_date: nil, history: [])
      @lookup_succeeded = lookup_succeeded
      @lookup_result = lookup_result
      @delivery_status = delivery_status
      @expected_delivery_date = expected_delivery_date
      @history = history
    end
  end
end