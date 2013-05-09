#!/bin/bash
# Script to synchronize formhub data with an osm instance

# load config
. sync_ipm.env

# TODO:
# - Handle errors

# Take backup of existing in case anything goes wrong
cp load_$OSM_ENV/existing.json load_$OSM_ENV/existing_bak.json

# - Get the latest data capture json from formhub
curl -u $FH_USER:$FH_PWD https://formhub.org/$FH_USER/forms/$FH_FORM/api > load_$OSM_ENV/latest.json 

# - Get diff of latest.json with existing.json and put it in new.json
if ! ./fh_json_diff.rb load_$OSM_ENV/existing.json load_$OSM_ENV/latest.json > load_$OSM_ENV/new.json; then
    exit 1
fi

# open a changeset and get its id
http_code=`curl -s -o changeset_id -w "%{http_code}" -u $OSM_USER:$OSM_PWD -d @changeset_new.xml -H "X_HTTP_METHOD_OVERRIDE: PUT" $OSM_SERVER/api/0.6/changeset/create`
if [[ $http_code != 200 ]]; then
    echo "FAILED to open changeset" >&2
    exit $http_code
fi

# load the changeset_id
CHANGESET_ID=`cat changeset_id`

# create the upload osm changeset file from new.json
if ! cat load_$OSM_ENV/new.json | ./json_to_osm.rb $CHANGESET_ID change > load_$OSM_ENV/osm_upload.osc; then
    exit 1
fi

# upload the changeset
http_code=`curl -s -o diff_response -w "%{http_code}" -u $OSM_USER:$OSM_PWD -d @load_$OSM_ENV/osm_upload.osc $OSM_SERVER/api/0.6/changeset/$CHANGESET_ID/upload`
if [[ $http_code != 200 ]]; then
    echo "FAILED to upload data" >&2
else
    # SUCCESS, so merge latest with existing dataset
    # ** canNOT just overwrite with latest since we may be pulling
    # ** from multiple forms
    ruby -e "require 'json'; existing = JSON.parse(File.read(\"load_$OSM_ENV/existing.json\")); new_json = JSON.parse(File.read(\"load_$OSM_ENV/new.json\")); merged = existing + new_json;  puts merged.to_json;" > load_$OSM_ENV/merged.json
    # Is this necessary?  Or can we write to existing.json in cmd above
    mv load_$OSM_ENV/merged.json load_$OSM_ENV/existing.json
fi

# close the changeset
curl -u $OSM_USER:$OSM_PWD -d @changeset_new.xml -H "X_HTTP_METHOD_OVERRIDE: PUT" $OSM_SERVER/api/0.6/changeset/$CHANGESET_ID/close
