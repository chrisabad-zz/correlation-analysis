require 'rubygems'
require 'mongo'
require 'ruby-progressbar'
require 'statsample'

include Mongo

# Connect to MongoDB
mongo_client = MongoClient.new
mongo_db = mongo_client.db("correlation_analysis")

# Get a list of all the events
sites_collection = mongo_db['sites']
puts "Getting a list of all events."
events = sites_collection.find_one['events'].map { |k,v| k }

# For each event, get the values and store in a dataset
raw_data = sites_collection.find({}, :fields => ['events']).map { |site| site['events'] }
sample_size = raw_data.size
puts "Building a dataset for #{events.size} events with a sample size of #{sample_size}."

event_data = {}
processed_data = {}
event_data['Converted'] = raw_data.map { |site| site['Converted'] }.to_scale

progress_bar = ProgressBar.create(
    :format => '%a |%B| %c of %C events.processed - %E',
    :title => "Progress",
    :total => events.size
)

events.each do |event|
	event_data[event] = raw_data.map { |site| site[event] }.to_scale
	processed_data[event] = {}
	pearson = Statsample::Bivariate::Pearson.new(event_data['Converted'], event_data[event])
	processed_data[event]['correlation'] = pearson.r
	processed_data[event]['probability'] = pearson.probability
	processed_data[event]['regression'] = Statsample::Regression::Simple.new_from_vectors(event_data['Converted'], event_data[event]).b
	
	# TODO: Calculate average time between registration and first occurance of the event.

	progress_bar.increment
end

event_types_collection = mongo_db['event_types']
event_types_collection.remove
processed_data.each do |k,v|
	event_type = {
		name: k,
		properties: v
	}
	event_types_collection.insert(event_type)
end