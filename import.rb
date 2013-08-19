require 'rubygems'
require 'mixpanel_client'
require 'csv'
require 'mongo'
require 'ruby-progressbar'

include Mongo

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

# Find earliest and latest registration date.
start_date = cohort.sort { |a,b| a['Registration Date'] <=> b['Registration Date'] }.first['Registration Date']
# Account for last trials by going 14 day beyond registration date.
end_date = cohort.sort { |a,b| b['Registration Date'] <=> a['Registration Date'] }.first['Registration Date'] + 14
puts "Preparing to import event data from #{start_date} to #{end_date}."

# Import event data for each day
days = (start_date..end_date).map { |date| date.to_s }
events_collection = mongo_db['events']
events_collection.remove
progress_bar = ProgressBar.create(
    :format => '%a |%B| %c of %C days imported - %E',
    :title => "Progress",
    :total => days.size
)

days.each do |day|
    begin
        event_data = mixpanel_client.request('export', {
            from_date:      day,
            to_date:        day,
            event:          events
        })
        events_collection.insert(event_data)
        progress_bar.increment
    rescue
        progress_bar.log('Another request is still in progress for this project. Will try again in 1 minute.')
        sleep 60
        retry
    end
end

