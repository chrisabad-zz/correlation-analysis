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

# Settings for CSV
csv_filename = 'cohort.csv'
csv_options = {
    headers:        :first_row,
    converters:     [ :numeric ] 
}

# Settings for Mixpanel
config = {api_key: 'ca805cc64eb5883cc5d8d4e79590312b', api_secret: 'e7413cb61a3df46eef549717e2b8a175'}
mixpanel_client = Mixpanel::Client.new(config)

# Connect to MongoDB
mongo_client = MongoClient.new
mongo_db = mongo_client.db("correlation_analysis")

# Get a list of all the events
events = mixpanel_client.request('events/names', { type: 'general' })
puts "Processing site event data across #{events.size} event types."

# Get a list of all the sites from the CSV
puts 'Importing the cohort.'
raw_cohort = CSV.read( csv_filename, csv_options )
cohort = []
raw_cohort.values_at('distinct_id', 'Registration Date', 'Conversion Date').each do |row|
    registration_date = Date.parse(row[1]).to_time.utc rescue nil
    conversion_date = Date.parse(row[2]).to_time.utc rescue nil

    cohort << {
        'distinct_id' => row[0].to_s,
        'properties' => {
        	'Registration Date' => registration_date,
        	'Conversion Date' => conversion_date
    	}
    }
end
puts "#{cohort.size} sites found in the cohort."

events_collection = mongo_db['events']
sites_collection = mongo_db['sites']
sites_collection.remove

progress_bar = ProgressBar.create(
    :format => '%a |%B| %c of %C sites imported - %E',
    :title => "Progress",
    :total => cohort.size
)

cohort.each do |site|
	site['events'] = {}

	# Grab all avilable events for the site between the registration and conversion date.
	site_events = events_collection.find({'properties.distinct_id' => site['distinct_id']}, :fields => ['event', 'properties.time']).to_a
	site_event_names = site_events.map { |site_event| site_event['event'] }.uniq
	
	# Iterate through each event, to see if there's at least one event
	events.each do |event_name|
		happened = site_event_names.include?(event_name)
		# Append results to document.
		site['events'][event_name] = {}
		site['events'][event_name]['happened'] = happened ? 1 : 0

		# If the event happened, determine when.
		if happened
			timestamp = site_events.select { |site_event| site_event['event'] == event_name }.first['properties']['time']

			# Calculate how long it took for the event to happen.
			site['events'][event_name]['time'] = (timestamp - site['properties']['Registration Date'])
		else
			site['events'][event_name]['time'] = nil
		end
	end

	# Indicate whether or not the site registered.
	site['events']['Converted'] = {}
	site['events']['Converted']['happened'] = site['properties']['Conversion Date'] ? 1 : 0
	site['events']['Converted']['time'] = site['properties']['Conversion Date'] ? (site['properties']['Conversion Date'] - site['properties']['Registration Date']) : nil

	# Insert document to MongoDB.
	sites_collection.insert(site)

	progress_bar.increment
end