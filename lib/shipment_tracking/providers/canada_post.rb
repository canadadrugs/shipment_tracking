require 'rest-client'
require 'base64'
require 'nokogiri'

# Tracking for Canada Post shipments. The auth_options parameter must be a Hash with :username and :password keys, which
# are provided to you in your Canada Post developer account under the "API Keys" section.
module ShipmentTracking
  class CanadaPost < Provider

    # https://www.canadapost.ca/cpo/mc/business/productsservices/developers/messagescodetables.jsf

    SUCCESSFUL_DELIVERY_EVENT_IDENTIFIERS = [
        '1408', # Item successfully delivered. Contact customer service for copy of signature.
        '1409', # Item successfully delivered. Contact customer service for copy of signature.
        '1421', # Item successfully delivered to recipient's front door
        '1422', # Item successfully delivered to recipient's side door
        '1423', # Item successfully delivered to recipient's back door
        '1424', # Item successfully delivered at or in recipient's garage
        '1425', # Item successfully delivered to building superintendent or security agent
        '1426', # Item successfully delivered to recipient's parcel box
        '1427', # Item successfully delivered to recipient's safe drop location
        '1428', # Item successfully delivered to recipient's front door
        '1429', # Item successfully delivered to recipient's side door
        '1430', # Item successfully delivered to recipient's back door
        '1431', # Item successfully delivered at or in recipient's garage
        '1432', # Item successfully delivered to building superintendent or security agent
        '1433', # Item successfully delivered to recipient's parcel box
        '1434', # Item successfully delivered to recipient's safe drop location
        '1441', # Item delivered to recipient's community mailbox.
        '1442', # Item delivered to recipient's community mailbox.
        '1496', # Item successfully delivered
        '1497', # Item successfully delivered to recipient's safe drop location
        '1498', # Item successfully delivered
        '1499', # Item successfully delivered to recipient's safe drop location
        '5300', # Item successfully delivered to recipient's parcel box
    ]

    FAILED_DELIVERY_EVENT_IDENTIFIERS = [
        '167', # International item being returned to sender. Insufficient international postage.
        '168', # International item being returned to sender. Does not meet product requirements.
        '169', # International item being returned to sender. Incorrect or missing shipping label
        '1100', # Refused by Customs. Unacceptable sender info. Item being returned to sender
        '1415', # Item being returned to Sender. Incomplete address.
        '1416', # Recipient not located at address provided. Item being returned to sender.
        '1417', # Item refused by recipient. Item being returned to sender.
        '1418', # Item being returned to Sender. Valid proof of age identification not provided.
        '1419', # Item was unclaimed by recipient. Item being returned to sender.
        '1420', # Item being returned to sender
        '1450', # Item arrived at the Undeliverable Mail Office. Please contact Cust Service
        '1481', # Item refused by recipient. Item being returned to sender.
        '1482', # Item refused or unclaimed by recipient. Item being returned to sender.
        '1483', # Item cannot be delivered as addressed; sent to the Undeliverable Mail Office
        '1491', # Item refused by recipient. Item being returned to sender.
        '1492', # Item refused or unclaimed by recipient. Item being returned to sender.
        '1493', # Item cannot be delivered as addressed; sent to the Undeliverable Mail Office
        '2600', # Item has been returned and is enroute to the Sender
        '3001', # Item being returned to sender
        '3002', # Authorized Return
    ]

    class << self

      protected

      def track_single(tracking_code, auth_options)
        begin
          response = make_request(tracking_code, auth_options.fetch(:username), auth_options.fetch(:password))
        rescue RestClient::Exception => ex
          return Shipment.new(lookup_succeeded: false, lookup_result: ex.response.nil? ? 'No response' : get_error_text(Nokogiri::XML(ex.response.body)))
        end

        return parse_response(response.body)
      end

      def make_request(tracking_code, username, password)
        RestClient::Request.execute(
            method: :get,
            url: "https://soa-gw.canadapost.ca/vis/track/pin/#{tracking_code}/detail",
            timeout: 10,
            headers: {
                "Authorization" => "Basic #{Base64.encode64("#{username}:#{password}")}",
                "Accept" => 'text/xml'
            }
        )
      end

      def parse_response(text)
        doc = Nokogiri::XML(text)

        failure_message = get_error_text(doc)
        return Shipment.new(lookup_succeeded: false, lookup_result: failure_message) if failure_message

        expected_delivery_date = to_date(doc.at_xpath('//xmlns:expected-delivery-date'))

        last_time_zone = Time.now.getlocal.zone
        # Canada Post puts the most recent first.
        history = doc.xpath('//xmlns:significant-events/xmlns:occurrence').reverse.map do |occurrence|
          date = to_date(occurrence.at_xpath('xmlns:event-date'))
          time = to_time(occurrence.at_xpath('xmlns:event-time'))
          tz = occurrence.at_xpath('xmlns:event-time-zone') ? occurrence.at_xpath('xmlns:event-time-zone').content : nil
          if date
            dt_args = [date.year, date.month, date.day]
            if time
              # Time zone is not reliably available, but we need to set it so things aren't always assumed to be GMT.
              # Just assume the last time zone still applies if we don't know.
              last_time_zone = tz || last_time_zone
              dt_args.concat([time.hour, time.min, time.sec, last_time_zone])
            end
            datetime = DateTime.new(*dt_args)
          end

          code = occurrence.at_xpath('xmlns:event-identifier').content
          description = occurrence.at_xpath('xmlns:event-description').content
          next HistoryEntry.new(date: datetime, code: code, description: description)
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

        return Shipment.new(lookup_succeeded: true, expected_delivery_date: expected_delivery_date, delivery_status: delivery_status, history: history)
      end

      def get_error_text(doc)
        el = doc.at_xpath('//xmlns:message/xmlns:description')
        return nil if el.nil?
        return el.content
      end

      def to_date(node)
        return nil if node.nil?
        return nil if node.content.empty?
        return Date.strptime(node.content, '%F')
      end

      def to_time(node)
        return nil if node.nil?
        return Time.strptime(node.content, '%T')
      end
    end
  end
end