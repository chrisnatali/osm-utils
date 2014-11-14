# Class to implement one-way sync of a PostGIS DB from an OSM API 
# Wraps retrieval of changesets from the OSM changeset API and 
# PostGIS population via osm2pgsql

require 'nokogiri' 
require 'date'
require 'fileutils'

class SyncLoad

  CHANGESET_DIR = "changesets"
  CHANGESET_ID_FILE = "changeset_ids.xml"
  
  def initialize(api_url, sync_dir, postgis_db, osm_pgsql_style_file)
    @api_url = api_url
    @sync_dir = sync_dir
    @postgis_db = postgis_db
    @osm_pgsql_style_file = osm_pgsql_style_file
    @changeset_dir = File.join(@sync_dir, CHANGESET_DIR)
    @changeset_id_file = File.join(@sync_dir, CHANGESET_ID_FILE)
  end

  # get all changesets since last update
  # return the max DateTime value from all new changesets
  def get_changesets(last_sync_timestamp)
   
    # get the changeset ids created since last time
    changeset_id_url = @api_url + "/api/0.6/changesets?time=" + 
                       last_sync_timestamp.to_s 
    system("curl #{changeset_id_url} > #{@changeset_id_file}")
 
    # parse them out and add all changeset files to CHANGESET_DIR
    doc = Nokogiri::XML(open(@changeset_id_file))
    ids = []
    closed_times = []    
    doc.xpath('//changeset').each do |ch| 
      ids << ch['id'] 
      closed_times << DateTime::parse(ch['closed_at'])
    end

    # now get the changeset files themselves
    # make sure changeset dir has been created
    FileUtils.mkdir_p(@changeset_dir)
    ids.each do |id|
      changeset_url = @api_url + "/api/0.6/changeset/#{id}/download"
      id_file = File.join(@changeset_dir, id.to_s) + ".osc"
      system("curl #{changeset_url} > #{id_file}")
    end
    
    closed_times.max() || last_sync_timestamp
  end


  # update DB with changeset files
  def update_postgis_with_changesets

    # run osm2pgsql for each changeset file
    Dir[File.join(@changeset_dir, "*.osc")].each do |id_file|
      osm2pgsql_cmd = "osm2pgsql --database #{@postgis_db} \
                                 --style #{@osm_pgsql_style_file} \
                                 --slim #{id_file} \
                                 --cache-strategy sparse \
                                 --hstore-all --extra-attributes --append"
      
      if system(osm2pgsql_cmd)
        FileUtils.mv id_file, id_file.sub("osc", "bak")
      end
    end

  end

end

require 'optparse'

options = {}
options[:config_file] = "./sync_load_cfg.rb"

optparse = OptionParser.new do |opts|
  opts.on('-g', '--get-changesets TIMESTAMP', 'get changesets since last sync') do |timestamp|
    options[:get_changesets] = DateTime::parse(timestamp)
  end

  opts.on('-u', '--update-postgis', 'update postgis with changesets') do 
    options[:update_postgis] = true
  end

  opts.on('-c', '--config-file CONFIG_FILE', 'set the ruby config file for constants') do |config_file|
    options[:config_file] = config_file
  end


  opts.on('-h', '--help', 'Display this screen') do
    puts opts
    exit
  end
end

begin
  optparse.parse!
  commands = [:get_changesets, :update_postgis]               
  selected_commands = commands.select{ |param| options[param] }
  if selected_commands.size < 1
    puts "Need to select at least one command of: #{commands.join(', ')}"
    puts optparse
    exit 1
  end

  # Read config and setup SyncLoad
  load options[:config_file]

  # check if nec vars are defined
  required_vars = [:SYNC_LOAD_API_URL, 
                   :SYNC_LOAD_SYNC_DIR, 
                   :SYNC_LOAD_POSTGIS_DB,
                   :SYNC_LOAD_STYLE_FILE]

  not_found_vars = required_vars - Object.constants
  if not_found_vars.size > 1
    puts "All variables need to be defined: #{required_vars.join(', ')}"
    exit 1
  end

  # make sure sync dir exists
  FileUtils.mkdir_p(SYNC_LOAD_SYNC_DIR)
  # Prevent multiple simultaneous runs
  lock_file = File.join(SYNC_LOAD_SYNC_DIR, "sync_load.lock") 
  if File.exists?(lock_file)
    puts "Already running"
    exit 1
  else
    File.open(lock_file, "w") {}
  end

  sync_load = SyncLoad.new(SYNC_LOAD_API_URL, 
                           SYNC_LOAD_SYNC_DIR, 
                           SYNC_LOAD_POSTGIS_DB, 
                           SYNC_LOAD_STYLE_FILE)

  if options[:get_changesets]
    last_cs_ts = sync_load.get_changesets(options[:get_changesets])
    puts last_cs_ts.to_s
  end

  if options[:update_postgis]
    sync_load.update_postgis_with_changesets
  end

  File.delete(lock_file)

rescue OptionParser::InvalidOption, OptionParser::MissingArgument      
  puts $!.to_s  # Friendly output when parsing fails
  puts optparse
  exit 1
end 
