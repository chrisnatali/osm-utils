#!/usr/bin/env ruby
# Ruby script to translate json file from FormHub into
# a corresponding osm file for upload to osm
# NOTE:
# ONLY handles NODE data (not ways/relations)
# TODO:
# - Make XML cleaner by looking at OSM examples
# - Prettify xml output

require 'rexml/document'


class ToOSM
    
    attr_reader :osm_xml

    OSM_DATA_VERSION = 1
    OSM_DEFAULT_CHANGESET = 1
    OSM_FILE_TYPE_OSM = "osm"
    OSM_FILE_TYPE_CHANGE = "change"

    def initialize(changeset_id=OSM_DEFAULT_CHANGESET, output_type=OSM_FILE_TYPE_OSM)
        @sequence = -1
        @changeset_id = changeset_id
        @output_type = output_type
        @osm_xml = REXML::Document.new
        @osm_xml_root = nil
        if @output_type == OSM_FILE_TYPE_CHANGE
            @osm_xml_root = @osm_xml.add_element("osmChange")
        else 
            @osm_xml_root = @osm_xml.add_element("osm")
        end
        @osm_xml_root.attributes["version"] = "0.6"
        @osm_xml_root.attributes["upload"] = "true"
        @osm_xml_root.attributes["generator"] = "ToOSM"
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

    def _node_xml(parent_node, id, lat, lon)
      node = parent_node.add_element("node")
      node.attributes["id"] = id
      node.attributes["visible"] = "true"
      node.attributes["version"] = OSM_DATA_VERSION
      node.attributes["changeset"] = @changeset_id
      node.attributes["lat"] = lat
      node.attributes["lon"] = lon
      node
    end

    def _add_tags_from_keys(node, record)
        (record.keys - ["lat", "lon", "simserial", "deviceid", "formhub/uuid", "meta/instanceID", "start", "node_location", "subscriberid", "today"]).each do |tag| 
            osm_tag = tag.gsub("/", ":")
            tag_xml = node.add_element("tag")
            tag_xml.attributes["k"] = osm_tag
            tag_xml.attributes["v"] = record[tag]
        end
    end

    # assumes record is a hash with "lat", "lon" keys, plus whatever keys we
    # want to add to the osm record tags.  The tags are named by the hash key,
    # so translation to osm tags should be done prior to this. 
    # ("lat", "lon" will be excluded from these)
    def record_to_osm_node(record)
        parent_node = @osm_xml_root
        if @output_type == OSM_FILE_TYPE_CHANGE
            parent_node = @osm_xml_root.add_element("create")
        end
        node = _node_xml(parent_node, get_sequence(), record["lat"], record["lon"])
        _add_tags_from_keys(node, record)
    end

end

require 'json'

HELP_TEXT = "Usage:  json_to_osm.rb changeset_id osm_file_type"

if ARGV.size != 2
    $stderr.puts HELP_TEXT
    exit 1
end

changeset_id = ARGV[0]
osm_file_type = ARGV[1]

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

to_osm = ToOSM.new(changeset_id, osm_file_type)

 
json_records.each {|json_record| to_osm.record_to_osm_node(json_record) }

formatter = REXML::Formatters::Pretty.new
formatter.compact = true
formatter.write(to_osm.osm_xml, $stdout)
