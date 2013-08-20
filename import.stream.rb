# This is a more efficient version of the import script. it
# uses the undocumented Mixpanel stream API to only import events
# for sites identified in the cohort, between the given site's 
# registration and conversion dates.

require 'rubygems'
require 'mixpanel_client'
require 'csv'
require 'mongo'
require 'ruby-progressbar'

include Mongo

# Warn before running script.
puts 'Running this script will reset all your data. Are you sure you want to do this ("yes" to continue)?'
unless gets.chomp.downcase == 'yes'
    puts 'Exiting the script.'
    exit
end

# Settings for Mixpanel
config = {api_key: 'ca805cc64eb5883cc5d8d4e79590312b', api_secret: 'e7413cb61a3df46eef549717e2b8a175'}
mixpanel_client = Mixpanel::Client.new(config)

# Settings for CSV
csv_filename = 'cohort.csv'
csv_options = {
    headers:        :first_row,
    converters:     [ :numeric ] 
}

# Connect to MongoDB
mongo_client = MongoClient.new
mongo_db = mongo_client.db("correlation_analysis")

# Get a list of all the events
events = mixpanel_client.request('events/names', { type: 'general' })
puts "Preparing to import data for #{events.size} event types."

# Get a list of all the sites from the CSV
puts 'Importing the cohort.'
raw_cohort = CSV.read( csv_filename, csv_options )
cohort = []
raw_cohort.values_at('distinct_id', 'Registration Date', 'Conversion Date').each do |row|
    registration_date = Date.parse(row[1]) rescue nil
    conversion_date = Date.parse(row[2]) rescue nil

    cohort << {
        'distinct_id' =>           row[0],
        'Registration Date' =>     registration_date,
        'Conversion Date' =>       conversion_date
    }
end
puts "#{cohort.size} sites found in the cohort."

events_collection = mongo_db['stream_events']
events_collection.remove
progress_bar = ProgressBar.create(
    :format => '%a |%B| %c of %C sites imported - %E',
    :title => "Progress",
    :total => cohort.size
)

cohort.each do |site|
    from_date = site['Registration Date'].to_s
    to_date = site['Conversion Date'] ? site['Conversion Date'].to_s : (site['Registration Date'] + 14).to_s

    event_data = mixpanel_client.request('stream/query', {
        from_date:      from_date,
        to_date:        to_date,
        distinct_ids:   ["#{site['distinct_id']}"]
    })

    # Before inserting, need to properly format the events.
    if event_data['results']['events'].size > 0
        events_collection.insert(event_data['results']['events'])
    end
    progress_bar.increment
end

