#!/usr/bin/env ruby
# Script to compare EXISTING and LATEST FormHub json record files
# to determine NEW FormHub json records and output them

require 'json'

HELP_TEXT = "Usage:  fh_json_diff.rb existing_file latest_file [primary_key]"

if ARGV.size < 2
    $stderr.puts HELP_TEXT
    exit 1 # return with error
end

existing_file = ARGV[0]
latest_file = ARGV[1]
primary_key = "_id"
if ARGV.size == 3
    primary_key = ARGV[2]
end

fh_existing_ids = []

# make sure latest file exists
if not File.exist?(latest_file)
    $stderr.puts "Fail:  latest_file: #{latest_file} does not exist"
    exit 1
end

if File.exist?(existing_file)
    fh_existing_json = JSON.parse(File.open(existing_file, "r").read)
    fh_existing_ids = fh_existing_json.map {|json_hash| json_hash[primary_key]}
end

fh_latest_json = JSON.parse(File.open(latest_file, "r").read)
fh_latest_ids = fh_latest_json.map {|json_hash| json_hash[primary_key]}

# Get the ids of the NEW records
fh_new_ids = fh_latest_ids - fh_existing_ids

# Find the NEW records in LATEST 
fh_new_json = fh_latest_json.find_all {|json_hash| fh_new_ids.include? json_hash[primary_key] }

# Write the NEW json to stdout
puts fh_new_json.to_json

