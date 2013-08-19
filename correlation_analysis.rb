require 'rubygems'
require 'mixpanel_client'
require 'csv'

# Set everything up
config = {api_key: 'ca805cc64eb5883cc5d8d4e79590312b', api_secret: 'e7413cb61a3df46eef549717e2b8a175'}
client = Mixpanel::Client.new(config)

csv_filename = 'cohort.csv'
csv_options = {
    headers:        :first_row,
    converters:     [ :numeric ] 
}

# Get a list of all the events
events = client.request('events/names', {
    type:           'general'
})

# Get a list of all the sites from the CSV
cohort = CSV.read( csv_filename, csv_options )
sites = []
cohort.values_at('distinct_id', 'Registration Date', 'Conversion Date').map { |row|
    sites << {
        distinct_id:           row[0],
        registration_date:     row[1],
        conversion_date:       row[2]
    }
}


# Grab events for site ID 141446
site_events = client.request('export', {
    from_date:      '2013-05-1',
    to_date:        '2013-05-1',
    event:          events,
    where:          '"144954" == properties["$distinct_id"]'
})