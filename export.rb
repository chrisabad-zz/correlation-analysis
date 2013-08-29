require 'rubygems'
require 'mongo'
require 'csv'
require 'ruby-progressbar'

include Mongo

# Connect to MongoDB
mongo_client = MongoClient.new
mongo_db = mongo_client.db("correlation_analysis")

puts "Importing data from database."
event_types_collection = mongo_db['event_types']
events = event_types_collection.find.to_a
sites_collection = mongo_db['sites']
sites = sites_collection.find.to_a

puts "Exporting raw data."
raw_data_progress_bar = ProgressBar.create(
    :format => '%a |%B| %c of %C sites processed - %E',
    :title => "Progress",
    :total => sites.size
)

# Export raw data
CSV.open("raw_data.csv", "wb") do |row|
  # Headers
  headers = ['distinct_id']
  event_names = sites.first['events'].map { |k,v| k }
  headers = headers + event_names
  row << headers

  sites.each do |site|
  	event_values = event_names.map { |name| site['events'][name] }
  	row << [site['distinct_id']] + event_values
  	raw_data_progress_bar.increment
  end
end

puts "Exporting analysis data."
analysis_data_progress_bar = ProgressBar.create(
    :format => '%a |%B| %c of %C events processed - %E',
    :title => "Progress",
    :total => events.size
)

# Export analysis data
CSV.open("correlation_analysis.csv", "wb") do |row|
  # Headers
  row << ["Event Name", "Correlation", "Strength", "Confidence", "Increase", "Occurs"]
  events.each do |event|
  	row << [ event['name'], event['properties']['correlation'], event['properties']['strength'], event['properties']['confidence'], event['properties']['increase'], event['properties']['occurs'] ]
  	analysis_data_progress_bar.increment
  end
end