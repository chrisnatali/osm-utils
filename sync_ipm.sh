#!/bin/bash

# load config
. sync_ipm.env

# TODO:
# - Handle errors

# - Get the latest data capture json from formhub
curl -u $FH_USER:$FH_PWD https://formhub.org/$FH_USER/forms/$FH_FORM/api > latest.json 

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
cat new.json | ruby json_to_osm.rb > osm_upload.osc

# upload the changeset
http_code=`curl -s -o diff_response -w "%{http_code}" -u $OSM_USER:$OSM_PWD -d @osm_upload.osc $OSM_SERVER/api/0.6/changeset/$CHANGESET_ID/upload`
if [[ $http_code != 200 ]]; then
    echo "FAILED to upload data"
else
    # SUCCESS, so set existing dataset to latest...since that's now in sync
    mv latest.json existing.json
fi

# close the changeset
curl -u $OSM_USER:$OSM_PWD -d @changeset_new.xml $OSM_SERVER/api/0.6/changeset/$CHANGESET_ID/close
