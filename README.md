Correlation Analysis
====================

A collection of scripts for analyzing the correlation between user events and trial conversion. Imports a CSV of the user cohort containing registration and conversion dates. Uses the Mixpanel export API to pull event data.

These scripts require that MongoDB be running in your environment.

You'll need to have a CSV file named `cohort.csv`, with the following columns:

* **distinct\_id** – This is the Desk.com site\_id, as well as the unique identifier in Mixpanel.
* **Registration Date** – When the site registered for trial, in the format 10-Jan-2013.
* **Conversion Date** – When the site converted to a customer, in the format 10-Jan-2013. If the site did not convert to a customer, the value of the column should be empty.

Here are the scripts provided. They do not need to be run all at once, but they do assume they're run in the order below.

* **import.rb** – This script will take all the sites identified in the cohort, and import all events from Mixpanel during their trial.
* **process.rb** – This script will take each site identified in the cohort, and indicate whether they did each available event at least once sometime during their trial.
* **correlation.rb** – This script will run correlation, significance, and regression analysis on the data from `process.rb`.
* **export.rb** – This script will export the output from `process.rb` to `raw_data.csv`, as well as the output from `correlation.rb` to `correlation_analysis.csv`.