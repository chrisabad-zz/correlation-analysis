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

converted_sites = raw_data.count { |site| site['Converted'] == 1 }
base_conversion_rate = converted_sites.to_f / sample_size.to_f
puts "Sample has a conversion rate of #{(base_conversion_rate * 100).round(2)}%"

puts "Building a dataset for #{events.size} unique event types with a sample size of #{sample_size}."
event_data = {}
processed_data = {}
event_data['Converted'] = raw_data.map { |site| site['Converted']['happened'] }.to_scale

progress_bar = ProgressBar.create(
    :format => '%a |%B| %c of %C events.processed - %E',
    :title => "Progress",
    :total => events.size
)

events.each do |event|
	event_data[event] = raw_data.map { |site| site[event]['happened'] }.to_scale
	processed_data[event] = {}
	pearson = Statsample::Bivariate::Pearson.new(event_data['Converted'], event_data[event])
	processed_data[event]['correlation'] = pearson.r.round(4)
	processed_data[event]['confidence'] = 1-pearson.probability.round(4)
	simple_regression = Statsample::Regression::Simple.new_from_vectors(event_data[event], event_data['Converted'])
	processed_data[event]['intercept'] = simple_regression.a.round(4)
	processed_data[event]['slope'] = simple_regression.b.round(4)
	processed_data[event]['increase'] = (simple_regression.b + simple_regression.a - base_conversion_rate).round(4)
	
	## Note strength of correlation
	begin
		correlation = (processed_data[event]['correlation'].abs * 10000).to_i
	rescue 
		correlation = 0
	end
	
	processed_data[event]['strength'] = case
	when correlation >= 7000
		'Very Strong'
	when correlation.between?(4000,7000)
		'Strong'
	when correlation.between?(3000,4000)
		'Moderate'
	when correlation.between?(2000,3000)
		'Weak'
	else	
		'Negligible'
	end

	# TODO: Calculate average time between registration and first occurance of the event.
	seconds_arr = raw_data.map { |site| site[event]['time'] }.compact	
	if seconds_arr.size != 0
		average_seconds = (seconds_arr.inject{ |sum, el| sum + el }.to_f / seconds_arr.size)
	else
		average_seconds = 0
	end	
	average_days = average_seconds.to_i / 86400
	processed_data[event]['occurs'] = "Day #{average_days+ 1}"

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