module ShipmentTracking
  class HistoryEntry
    attr_reader :date, :code, :description

    def initialize(date: nil, code: nil, description: nil)
      @date = date
      @code = code
      @description = description
    end
  end
end