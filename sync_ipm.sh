#!/bin/bash

# load config
. sync_ipm.env

# TODO:
# - Get the latest data capture json from formhub
# - Get diff of latest with base json and put it in osm_upload.json
# - Handle errors

# open a changeset and get its id
CHANGESET_ID=`curl -u $OSM_USER:$OSM_PWD -d @changeset_new.xml -H "X_HTTP_METHOD_OVERRIDE: PUT" $OSM_SERVER/api/0.6/changeset/create`
return_code=$?
if [[ $return_code != 0 ]]; then
    echo "FAILED to open changeset"
    exit $return_code
fi

# store the changeset id in the cfg
sed "s/%change_id%/$CHANGESET_ID/" to_osm_cfg_tmpl.rb > to_osm_cfg.rb

# create the upload osm changeset file
cat osm_upload.json | ruby json_to_osm.rb > osm_upload.osc

# upload the changset
curl -u $OSM_USER:$OSM_PWD -d @osm_upload.osc $OSM_SERVER/api/0.6/changeset/$CHANGESET_ID/upload

# close the changeset
curl -u $OSM_USER:$OSM_PWD -d @changeset_new.xml $OSM_SERVER/api/0.6/changeset/$CHANGESET_ID/close
