# Class to implement one-way sync of a PostGIS DB from an OSM API 
# Wraps retrieval of changesets from the OSM changeset API and 
# PostGIS population via osm2pgsql

class SyncLoad

  CHANGESET_DIR = "changesets"
  LAST_SYNC_TIMESTAMP_FILE = ".last_sync_timestamp"
  
  def initialize(api_url, sync_dir, postgis_db, osm_pgsql_style_file)
    @api_url = api_url
    @sync_dir = sync_dir
    @postgis_db = postgis_db
    @osm_pgsql_style_file = osm_pgsql_style_file
  end

  # get all changesets since last update
  def get_changesets()
   
    # this will clobber last changeset_id osc file
    @api_url + "/api/0.6/changesets?time="`cat #{LAST_SYNC_TIMESTAMP_FILE}`

  end
