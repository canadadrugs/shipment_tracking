require 'savon'

module ShipmentTracking
  class Dhl < Provider

    protected

    def track_single(tracking_code, auth_options)
      track_multiple([tracking_code], auth_options) { |tracking_id, result| return result }
    end

    def track_multiple(tracking_codes, auth_options)
      parse_shipment_status_response(perform_request(tracking_codes)) { |tracking_id, result| yield tracking_id, result }
    end

    def perform_request(ref_ids)
      client = Savon.client({
                                wsse_auth: [SITE_ID, PASSWORD],
                                wsse_timestamp: true,
                                convert_request_keys_to: :camelcase,
                                namespaces: {
                                    "xmlns:dhl" => "http://www.dhl.com"
                                },
                                #ssl_verify_mode: :none # Until we can figure what's wrong with SSL
                                wsdl: 'https://wsbuat.dhl.com:8300/gbl/glDHLExpressTrack?WSDL'
                            })
      return client.call(:track_shipment_request, message: shipment_status_request(ref_ids)).body
    end

    def shipment_status_request(ref_ids)
      {
          'trackingRequest' => {
              'dhl:TrackingRequest' => {
                  request: {
                      service_header: {
                          message_time: Time.now.strftime('%Y-%m-%dT%H:%M:%S%:z'),
                          message_reference: '1234567890123456789012345678' # Ref between 28 and 32 characters
                      }
                  },
                  a_w_b_number: {
                      array_of_a_w_b_number_item: ref_ids
                  },
                  # lp_number: nil, # Inactive in API
                  level_of_details: 'LAST_CHECK_POINT_ONLY',
                  pieces_enabled: 'S' # B for Both, S for shipment details only, P for piece details only
              }
          }
      }
    end

    def parse_shipment_status_response(h)
      h[:track_shipment_request_response][:tracking_response][:tracking_response][:awb_info][:array_of_awb_info_item].each do |awb|
        ref_id = awb[:awb_number]
        request_status = aqb[:status][:action_status]
        if request_status != 'success'
          yield ref_id, Shipment.new(lookup_succeeded: false)
          next
        end
        event = awb[:shipment_info][:shipment_event]
        date = event[:date]
        time = event[:time]
        date_time = DateTime.strptime("#{date}T#{time}")
        status_text = event[:service_event][:description]
        event_code = event[:service_event][:event_code]
        status = if SUCCESS_CODES.include?(event_code)
                   DeliveryStatus::COMPLETE
                 elsif FAILURE_CODES.include?(event_code)
                   DeliveryStatus::FAILED
                 else
                   DeliveryStatus::IN_PROGRESS
                 end
        yield ref_id, Shipment.new(lookup_succeeded: true, delivery_status: status)
      end
    end

  end
end
