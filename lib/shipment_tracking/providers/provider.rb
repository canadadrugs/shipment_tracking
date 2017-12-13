# Superclass for tracking providers. Subclasses must implement track_single(tracking_code). Subclasses should also
# implement track_multiple(tracking_codes) if there is a method for looking up multiple results at once.
module ShipmentTracking
  class Provider
    class << self

      # Looks up shipment tracking info from the provider.
      #
      # If tracking_codes is an Enumerable, it will return an Enumerator that yields the tracking ID and Shipment
      # result. Otherwise, it will simply return a Shipment result.
      #
      # auth_options are any options required by specific providers to be able to make this request.
      def track(tracking_codes, auth_options)
        return enum_for(:track_multiple, tracking_codes, auth_options) if tracking_codes.is_a?(Enumerable)
        return track_single(tracking_codes, auth_options)
      end

      protected

      def track_multiple(tracking_codes, auth_options)
        tracking_codes.each do |tracking_code|
          yield tracking_code, track_single(tracking_code, auth_options)
        end
      end
    end
  end
end