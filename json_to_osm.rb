# Ruby script to translate json file from FormHub into
# a corresponding osm file for upload to osm
# NOTE:
# ONLY handles NODE data (not ways/relations)
# TODO:
# - Make XML cleaner by looking at OSM examples
# - Prettify xml output
# - Test posting to OSM


class ToOSM
    
    XML_INIT = "<?xml version='1.0' encoding='UTF-8'?>\n"
    OSM_ROOT = "<osm version='0.6' upload='true' generator='ToOSM'>\n"
    OSM_CHANGE_ROOT = "<osmChange version='0.6' upload='true' generator='ToOSM'>\n"
    OSM_END = "</osm>\n"
    OSM_CHANGE_END = "</osmChange>\n"
    OSM_NODE_END = "</node>\n"
    OSM_DATA_VERSION = 1
    OSM_DEFAULT_CHANGESET = 1
    OSM_FILE_TYPE_OSM = "osm"
    OSM_FILE_TYPE_CHANGE = "change"

    def initialize(changeset_id=OSM_DEFAULT_CHANGESET, output_type=OSM_FILE_TYPE_OSM)
        @sequence = -1
        @changeset_id = changeset_id
        @output_type = output_type
    end

    #TODO:  Figure out how to auto-comment similar to auto-indent
#    def record_to_hash(record)
#        record_hash = {}
#        0.upto(@keys.length) do |i| 
#            key = keys[i]
#            val = record[i]
#            record_hash[key] = val
#        end
#        record_hash
#    end

#   #for record value lookup via header field name
#   def field_lookup(field, record)
#       record[@field_index[field]]
#   end

#   #for record value lookup via tag field name
#   def tag_lookup(tag, record)
#       field = @merged_tag_map[tag]
#       field_lookup(field, record)
#   end

    def get_sequence()
        seq = @sequence
        @sequence -= 1
        seq
    end

    def _node_xml(id, lat, lon)
      "<node id='#{id}' visible='true' version='#{OSM_DATA_VERSION}' changeset='#{@changeset_id}' lat='#{lat}' lon='#{lon}'>\n"
    end

    def _keys_to_tags(record)
        tag_string = ""
        (record.keys - ["lat", "lon", "simserial", "deviceid", "formhub/uuid", "meta/instanceID", "start", "node_location", "subscriberid", "today"]).each do |tag| 
            osm_tag = tag.gsub("/", ":")
            tag_string << "<tag k='#{osm_tag}' v='#{record[tag]}' />\n"
        end
        tag_string
    end

    # assumes record is a hash with "lat", "lon" keys, plus whatever keys we
    # want to add to the osm record tags.  The tags are named by the hash key,
    # so translation to osm tags should be done prior to this. 
    # ("lat", "lon" will be excluded from these)
    def record_to_osm_node(record)
        xml = ""
        if @output_type == OSM_FILE_TYPE_CHANGE
            xml << "<create>\n"
        end 
        xml << _node_xml(get_sequence(), record["lat"], record["lon"])
        xml << _keys_to_tags(record)
        xml << OSM_NODE_END
        if @output_type == OSM_FILE_TYPE_CHANGE
            xml << "</create>\n"
        end 
        xml
    end

end

require 'json'

# read in options from config file if it exists
# let it fail if no config file
require './to_osm_cfg.rb'


# Read formhub json from stdin for now
formhub_json = JSON.parse($stdin.read)

# convert the json into list of hashes suitable for import into OSM
# via ToOSM

json_records = formhub_json.map do |json_hash| 
    h_rec = { 
               "lat" => json_hash['_geolocation'][0], 
               "lon" => json_hash['_geolocation'][1]
            }
            
    # simply get all 
    json_hash.keys.each do |key|
       h_rec[key] = json_hash[key] if not key.match(/^_/)
    end 

    # add formhub as source and its id
    h_rec["source"] = "http://formhub.org"
    h_rec["source:id"] = json_hash["_id"]

    h_rec
end

to_osm = ToOSM.new(ToOSMConfig::CHANGESET_ID, ToOSMConfig::OSM_FILE_TYPE)

# puts header
# csv.each {|csv_record| puts csv_to_osm.field_lookup("Name", csv_record) }
# Write out the xml
puts ToOSM::XML_INIT
if ToOSMConfig::OSM_FILE_TYPE == ToOSM::OSM_FILE_TYPE_CHANGE
    puts ToOSM::OSM_CHANGE_ROOT
else
    puts ToOSM::OSM_ROOT
end
 
json_records.each {|json_record| puts to_osm.record_to_osm_node(json_record) }

if ToOSMConfig::OSM_FILE_TYPE == ToOSM::OSM_FILE_TYPE_CHANGE
    puts ToOSM::OSM_CHANGE_END
else
    puts ToOSM::OSM_END
end
