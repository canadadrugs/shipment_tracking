# Shipment Tracking

Get shipment tracking data. Supported providers:

- USPS
- UPS
- Canada Post

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'shipment_tracking'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install shipment_tracking

## Usage

Provider APIs require you to have an account with their service. Each will require some combination of username, password, and key.

Tracking a single package with UPS:

```ruby
require 'shipment_tracking'
result = ShipmentTracking::UPS.track('YOUR_SHIPMENT_TRACKING_ID', username: Rails.application.secrets[:ups_username], password: Rails.application.secrets[:ups_password], access_key: Rails.application.secrets[:ups_key])
puts result.delivery_status
# => complete
puts result.history.last.date
# => 2017-11-20T13:49:00-06:00
puts result.history.last.description
# => Delivered
```

Some providers may allow multiple lookups in a single request, so you can use the form to improve performance:

```ruby
require 'shipment_tracking'
ShipmentTracking::UPS.track(['YOUR_SHIPMENT_TRACKING_ID_1', 'YOUR_SHIPMENT_TRACKING_ID_2'], username: Rails.application.secrets[:ups_username], password: Rails.application.secrets[:ups_password], access_key: Rails.application.secrets[:ups_key]).each do |tracking_id, result|
  # Process each one here
end
```

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

