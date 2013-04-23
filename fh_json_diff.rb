# Script to compare EXISTING and LATEST FormHub json record files
# to determine NEW FormHub json records and output them
require 'json'

# load config params from FHJsonDiffCfg module
require './fh_json_diff_cfg.rb'

# def extract_ids(formhub_json)
#    fromhub_json.map {|json_hash| json_hash[FHJsonDiffCfg::PRIMARY_KEY]}
# end
 
fh_existing_ids = []

if File.exist?(FHJsonDiffCfg::EXISTING_FILE)
    fh_existing_json = JSON.parse(File.open(FHJsonDiffCfg::EXISTING_FILE, "r").read)
    fh_existing_ids = fh_existing_json.map {|json_hash| json_hash[FHJsonDiffCfg::PRIMARY_KEY]}
end

# LATEST file should always exist or this script shouldn't be called
fh_latest_json = JSON.parse(File.open(FHJsonDiffCfg::LATEST_FILE, "r").read)
fh_latest_ids = fh_latest_json.map {|json_hash| json_hash[FHJsonDiffCfg::PRIMARY_KEY]}

# Get the ids of the NEW records
fh_new_ids = fh_latest_ids - fh_existing_ids

# Find the NEW records in LATEST 
fh_new_json = fh_latest_json.find_all {|json_hash| fh_new_ids.include? json_hash[FHJsonDiffCfg::PRIMARY_KEY] }

# Write out the NEW json
File.open(FHJsonDiffCfg::NEW_FILE, "w") do |f|
      f.write(fh_new_json.to_json)
end

# All File Streams should auto-close at end of script
