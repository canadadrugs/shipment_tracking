require 'rest-client'
require 'json'

# Tracking for Canada Post shipments. The auth_options parameter must be a Hash with :username, :password, and
# :access_key keys.
module ShipmentTracking
  class UPS < Provider

    # From https://www.ups.com/content/ca/en/tracking/tracking/description.html, but that doesn't say what the code is.

    SUCCESSFUL_DELIVERY_EVENT_IDENTIFIERS = [
      'KB', # Delivered
      'FS', # Delivered
      'F4', # Delivered
      'KM', # Delivered
      '2W', # Customer has picked up package at UPS Access Point™.
    ]

    FAILED_DELIVERY_EVENT_IDENTIFIERS = [

    ]

    class << self

      protected

      def track_single(tracking_code, auth_options)
        begin
          response = make_request(tracking_code, auth_options.fetch(:username), auth_options.fetch(:password), auth_options.fetch(:access_key))
        rescue RestClient::Exception => ex
          return Shipment.new(lookup_succeeded: false, lookup_result: get_error_text(Nokogiri::XML(ex.response.body)))
        end

        return parse_response(response.body)
      end

      def make_request(tracking_code, username, password, access_key)
        RestClient.post(
            "https://onlinetools.ups.com/rest/Track",
            JSON.generate({
                "UPSSecurity": {
                    "UsernameToken": {
                        "Username": username, "Password": password
                    },
                    "ServiceAccessToken": {
                        "AccessLicenseNumber": access_key
                    }
                },
                "TrackRequest": {
                  "Request": {
                      "RequestOption": "1", "TransactionReference": {
                        "CustomerContext": "Your Test Case Summary Description"
                      }
                  },
                  "InquiryNumber": tracking_code
                }
            }),
            content_type: 'application/json',
            timeout: 10,
            headers: {
                "Authorization" => "Basic #{Base64.encode64("#{username}:#{password}")}",
                "Accept" => 'text/xml'
            }
        )
      end

      def parse_response(text)
        doc = JSON.parse(text)

        failure_message = get_error_text(doc)
        return Shipment.new(lookup_succeeded: false, lookup_result: failure_message) if failure_message

        shipment_info = doc['TrackResponse']['Shipment']

        # Usually one package, but can be multiple. Just pick the first one.
        package = shipment_info['Package']
        package = package.first if package.is_a?(Array)

        # UPS puts the most recent first. This can be an Array if multiple or a Hash if one.
        activities = package['Activity']
        activities = [activities] if !activities.is_a?(Array)
        activities = activities.reverse

        history = activities.map do |activity|
          history_date = to_date(activity['Date'])
          history_time = to_time(activity['Time'])
          # Time is "local time", so assume that's us.
          history_datetime = DateTime.new(history_date.year, history_date.month, history_date.day, history_time.hour, history_time.min, history_time.sec, Time.now.getlocal.zone)
          history_description = activity['Status']['Description']
          history_code = activity['Status']['Code']
          HistoryEntry.new(date: history_datetime, code: history_code, description: history_description)
        end

        if history.any?
          delivery_status = case history.last.code
                              when *SUCCESSFUL_DELIVERY_EVENT_IDENTIFIERS
                                DeliveryStatus::COMPLETE
                              when *FAILED_DELIVERY_EVENT_IDENTIFIERS
                                DeliveryStatus::FAILED
                              else
                                DeliveryStatus::IN_PROGRESS
                            end
        end

        return Shipment.new(lookup_succeeded: true, delivery_status: delivery_status, history: history)
      end

      def get_error_text(doc)
        return doc['Fault']['detail']['Errors']['ErrorDetail']['PrimaryErrorCode']['Description'] if doc['Fault']
        return nil if doc['TrackResponse']['Response']['ResponseStatus']['Code'] == '1'
        return doc['TrackResponse']['Response']['ResponseStatus']['Description']
      end

      def to_date(text)
        return nil if text.empty?
        return Date.strptime(text, '%Y%m%d')
      end

      def to_time(text)
        return nil if text.empty?
        return Time.strptime(text, '%H%M%S')
      end
    end
  end
end