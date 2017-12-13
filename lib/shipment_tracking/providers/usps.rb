require 'rest-client'

module ShipmentTracking
  class USPS < Provider
    class << self

      protected

      def track_single(tracking_code, auth_options)
        begin
          response = make_request(tracking_code, auth_options.fetch(:username))
        rescue RestClient::Exception => ex
          return Shipment.new(lookup_succeeded: false, lookup_result: ex)
        end

        return parse_response(response.body)
      end

      def make_request(tracking_code, username)
        RestClient::Request.execute(
            method: :get,
            url: "http://production.shippingapis.com/ShippingAPI.dll?API=TrackV2&XML=%3CTrackRequest%20USERID=%22#{username}%22%3E%3CTrackID%20ID=%22#{tracking_code}%22%3E%3C/TrackID%3E%3C/TrackRequest%3E",
            timeout: 10,
        )
      end

      def parse_response(text)
        doc = Nokogiri::XML(text)

        failure_message = get_error_text(doc)
        return Shipment.new(lookup_succeeded: false, lookup_result: failure_message) if failure_message

        additional_history_entries = []

        status_string = doc.at_xpath('//TrackSummary').content
        if status_string.include?('The Postal Service could not locate')
          return Shipment.new(lookup_succeeded: false, lookup_result: status_string)
        end
        if ['Your item was delivered', 'Your item was picked up', 'Your item has been delivered'].any?{|s| status_string.include?(s)}
          status = DeliveryStatus::COMPLETE
          # This item for some reason is not added as a TrackDetail. See if we can make one up.
          match = /(?:Your item was delivered in or at the mailbox at|Your item was picked up at the post office at|Your item has been delivered and is available at a PO Box at) (.*?) on (.*?) in/.match(status_string)
          if match && match.captures.size == 2
            date = DateTime.strptime(match.captures[1] + ' ' + match.captures[0] + ' CDT', '%B %e, %Y %l:%M %P %Z')
            additional_history_entries << HistoryEntry.new(date: date, code: 'Your item was picked up', description: status_string)
          end
        else
          status = DeliveryStatus::IN_PROGRESS
        end

        history = doc.xpath('//TrackDetail').reverse.map do |occurrence|
          history_text = occurrence.content
          history_parts = history_text.split(', ')
          code = history_parts[0]
          date = nil
          if history_parts.length >= 4
            # The month/day is the first part of the date. Ordinarily this is element index 1, but the initial text can
            # contain commas like "Moved, left no address". So find where the date starts.
            date_start_index = history_parts.index{|hp| Date::MONTHNAMES.compact.any?{|month| hp.starts_with?(month)} }
            if date_start_index.present?
              # Assume our time zone, I guess...
              begin
                date = DateTime.strptime(history_parts[date_start_index..(date_start_index + 2)].join(' ') + ' CDT', '%B %e %Y %l:%M %P %Z')
              rescue ArgumentError => ex
                # We can be thrown off by things like "Rescheduled to Next Delivery Day, October 3, 2017, DULUTH, MN 55802"
                # where there is no time provided.
                Rails.logger.warn("Could not parse date for entry '#{history_text}'.") if defined?(Rails)
              end
            end
          end
          HistoryEntry.new(date: date, code: code, description: history_text)
        end

        return Shipment.new(lookup_succeeded: true, delivery_status: status, history: history + additional_history_entries)
      end

      def get_error_text(doc)
        el = doc.at_xpath('//Error/Description')
        return nil if el.nil?
        return el.content
      end

    end

  end
end