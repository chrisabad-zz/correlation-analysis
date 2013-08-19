require 'rubygems'
require 'mixpanel_client'

# Set everything up
config = {api_key: 'ca805cc64eb5883cc5d8d4e79590312b', api_secret: 'e7413cb61a3df46eef549717e2b8a175'}
client = Mixpanel::Client.new(config)

# Get a list of all the events
events = client.request('events/names', {
    type:           'general'
})
# puts events.inspect

# Get all the sites that registered between 4/16/13 and 7/16/13
registration_events = client.request('export', {
    from_date:      '2013-04-16',
    to_date:        '2013-04-16',
    # to_date:        '2013-07-16',
    event:          ['Registered']    
})

site_events = client.request('export', {
    from_date:      '2013-04-16',
    to_date:        '2013-04-16',
    # to_date:        '2013-07-16',
    event:          ['Resolved Case'],
    where:          'properties["distinct_id"' == 141330

})

sites = registration_events.map { |event| event.select { |key, value| ['disc'] } }
puts sites.inspect