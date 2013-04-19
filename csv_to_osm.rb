# Ruby script to translate csv file of lat/long + keys into
# a corresponding osm file for upload to osm
# NOTE:
# ONLY handles NODE data (not ways/relations)
# TODO:
# - Make CSV cleaner via CSV module (look at OSM code examples)
# - Make XML cleaner by looking at OSM examples
# - Prettify xml output
# - Test posting to OSM


class CSVToOSM
    
    XML_INIT = "<?xml version='1.0' encoding='UTF-8'?>\n"
    OSM_ROOT = "<osm version='0.6' upload='true' generator='CSVToOSM'>\n"
    OSM_CHANGE_ROOT = "<osmChange version='0.6' upload='true' generator='CSVToOSM'>\n"
    OSM_END = "</osm>\n"
    OSM_CHANGE_END = "</osmChange>\n"
    OSM_NODE_END = "</node>\n"
    OSM_DATA_VERSION = 1
    OSM_DEFAULT_CHANGESET = 1
    OSM_FILE_TYPE_OSM = "osm"
    OSM_FILE_TYPE_CHANGE = "change"

    def initialize(header, node_tag_map, field_tag_map, changeset_id=OSM_DEFAULT_CHANGESET, output_type=OSM_FILE_TYPE_OSM)
        @sequence = -1
        @changeset_id = changeset_id
        @output_type = output_type
        @fields = header
        @field_index = {}
        0.upto(@fields.length) do |i|
            @field_index[@fields[i]] = i
        end
        #TODO:  Validate that there are lat/lon fields
        @node_tag_map = node_tag_map
        @tag_map = field_tag_map
        @merged_tag_map = @node_tag_map.merge(@tag_map)
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

    #for record value lookup via header field name
    def field_lookup(field, record)
        record[@field_index[field]]
    end

    #for record value lookup via tag field name
    def tag_lookup(tag, record)
        field = @merged_tag_map[tag]
        field_lookup(field, record)
    end

    def get_sequence()
        seq = @sequence
        @sequence -= 1
        seq
    end

    def _node_xml(id, lat, lon)
      "<node id='#{id}' visible='true' version='#{OSM_DATA_VERSION}' changeset='#{@changeset_id}' lat='#{lat}' lon='#{lon}'>\n"
    end

    def _keys_to_tags(record)
        #TODO:  Make this more efficient (check CSV osm code)
        tag_string = ""
        @tag_map.keys.each do |tag| 
            tag_string << "<tag k='#{tag}' v='#{tag_lookup(tag, record)}' />\n"
        end
        tag_string
    end

    def record_to_osm_node(record)
        xml = ""
        if @output_type == OSM_FILE_TYPE_CHANGE
            xml << "<create>\n"
        end 
        xml << _node_xml(get_sequence(), tag_lookup("lat", record), tag_lookup("lon", record))
        xml << _keys_to_tags(record)
        xml << OSM_NODE_END
        if @output_type == OSM_FILE_TYPE_CHANGE
            xml << "</create>\n"
        end 
        xml
    end

end

require 'csv'
require 'optparse'


#read in options from config file if it exists
# let it fail if no config file
require './to_osm_cfg.rb'

# Read CSV from stdin for now
csv = CSV($stdin)

# Read header 1st
header = csv.shift

# hard-coded keys/tags for now
osm_node_map = {"lon" => "Longitude", "lat" => "Latitude"}
osm_tag_map = {"name" => "Name"}

csv_to_osm = CSVToOSM.new(header, osm_node_map, osm_tag_map, ToOSMConfig::CHANGESET_ID, ToOSMConfig::OSM_FILE_TYPE)

# puts header
# csv.each {|csv_record| puts csv_to_osm.field_lookup("Name", csv_record) }
# Write out the xml
puts CSVToOSM::XML_INIT
if ToOSMConfig::OSM_FILE_TYPE == CSVToOSM::OSM_FILE_TYPE_CHANGE
    puts CSVToOSM::OSM_CHANGE_ROOT
else
    puts CSVToOSM::OSM_ROOT
end
 
csv.each {|csv_record| puts csv_to_osm.record_to_osm_node(csv_record) }

if ToOSMConfig::OSM_FILE_TYPE == CSVToOSM::OSM_FILE_TYPE_CHANGE
    puts CSVToOSM::OSM_CHANGE_END
else
    puts CSVToOSM::OSM_END
end
