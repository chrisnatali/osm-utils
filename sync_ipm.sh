#!/bin/bash

# load config
. sync_ipm.env

# TODO:
# - Handle errors

# Take backup of existing in case anything goes wrong
cp load_$OSM_ENV/existing.json load_$OSM_ENV/existing_bak.json

# - Get the latest data capture json from formhub
curl -u $FH_USER:$FH_PWD https://formhub.org/$FH_USER/forms/$FH_FORM/api > load_$OSM_ENV/latest.json 

# - Get diff of latest.json with existing.json and put it in new.json
ruby fh_json_diff.rb

# open a changeset and get its id
http_code=`curl -s -o changeset_id -w "%{http_code}" -u $OSM_USER:$OSM_PWD -d @changeset_new.xml -H "X_HTTP_METHOD_OVERRIDE: PUT" $OSM_SERVER/api/0.6/changeset/create`
if [[ $http_code != 200 ]]; then
    echo "FAILED to open changeset"
    exit $http_code
fi

# store the changeset id in the cfg
CHANGESET_ID=`cat changeset_id`
sed "s/%change_id%/$CHANGESET_ID/" to_osm_cfg_tmpl.rb > to_osm_cfg.rb

# create the upload osm changeset file from new.json
cat load_$OSM_ENV/new.json | ruby json_to_osm.rb > load_$OSM_ENV/osm_upload.osc

# upload the changeset
http_code=`curl -s -o diff_response -w "%{http_code}" -u $OSM_USER:$OSM_PWD -d @osm_upload.osc $OSM_SERVER/api/0.6/changeset/$CHANGESET_ID/upload`
if [[ $http_code != 200 ]]; then
    echo "FAILED to upload data"
else
    # SUCCESS, so merge latest with existing dataset
    # ** canNOT just overwrite with latest since we may be pulling
    # ** from multiple forms
    ruby -e "require 'json'; existing = JSON.parse(File.read(\"load_$OSM_ENV/existing.json\")); new = JSON.parse(File.read(\"load_$OSM_ENV/new.json\")); merged = existing + new;  puts merged.to_json;" > load_$OSM_ENV/merged.json
    # Is this necessary?  Or can we write to existing.json in cmd above
    mv load_$OSM_ENV/merged.json load_$OSM_ENV/existing.json
fi

# close the changeset
curl -u $OSM_USER:$OSM_PWD -d @changeset_new.xml -H "X_HTTP_METHOD_OVERRIDE: PUT" $OSM_SERVER/api/0.6/changeset/$CHANGESET_ID/close
