Utilities for working with OSM data
----------------------------------

sync_ipm.sh:  script to do a one-way sync of FormHub data into an OSM instance
json_to_osm.rb:  script to convert FormHub-based json output into an OSM changset suitable for loading into an OSM instance

Setting up a tile server
------------------------

Use osmosis to extract osm data from an "API" database:
```
osmosis --read-apidb database="osm" user="osm" password="<osm_password>" allowIncorrectSchemaVersion="yes" --write-xml file="planet.osm"
```

Use osm2pgsql on the tile server to write the extract data to a postgis db:
```
osm2pgsql --database gis_pln --style gridmaps_pgsql.style --slim planet.osm --hstore
```

You can point a tile server (i.e. TileStache) at the postgis db to generate/serve tiles



