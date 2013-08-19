require 'rubygems'
require 'mixpanel_client'
require 'csv'
require 'date'

# Settings for Mixpanel
config = {api_key: 'ca805cc64eb5883cc5d8d4e79590312b', api_secret: 'e7413cb61a3df46eef549717e2b8a175'}
client = Mixpanel::Client.new(config)

# Settings for CSV
csv_filename = 'cohort.csv'
csv_options = {
    headers:        :first_row,
    converters:     [ :numeric ] 
}

# For testing purposes, restrict the data set
limit = 5

# Get a list of all the events
events = client.request('events/names', {
    type:           'general'
})

# Get a list of all the sites from the CSV
puts 'Reading the CSV file.'
cohort = CSV.read( csv_filename, csv_options )
puts "Done reading the CSV file. #{cohort.size} rows found."
sites = []
puts 'Stripping down the list of sites.'
cohort.values_at('distinct_id', 'Registration Date', 'Conversion Date').each do |row|
    registration_date = Date.parse(row[1]) rescue nil
    conversion_date = Date.parse(row[2]) rescue nil

    sites << {
        'distinct_id' =>           row[0],
        'Registration Date' =>     registration_date,
        'Conversion Date' =>       conversion_date
    }
end
puts 'Done stripping down the list of sites.'
puts "Limiting to #{limit} sites."
index = 0
sites = sites[0,limit]

# For each site, grab its events and process
sites.each do |site|
    to_date = if site['Conversion Date'] then site['Conversion Date'] else (site['Registration Date'] + 14) end
    puts "Getting events for site #{index+1} of #{sites.size}. Looking for events from #{site['Registration Date'].to_s} to #{to_date.to_s}."

    # Export all events for the site between its registration date, and its conversion date
    site_events = client.request('export', {
        from_date:      site['Registration Date'].to_s,
        
        # These are for dev purposes, to keep the data set small.

        # to_date:        to_date.to_s,
        # event:          events
        
        where:          "#{site['distinct_id']} == properties['distinct_id']"
    })
    puts "Found #{site_events.size} events."

    # TODO: For each site, iterate through the event names and indicate if at least one
    # instance of the event exists in the returned events

    index += 1
end