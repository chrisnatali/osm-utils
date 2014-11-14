#!/bin/bash

# Assumes this script is being run from the same dir as the sync_load.rb ruby script
SYNC_DIR=/home/tiles/sync_load

mkdir -p $SYNC_DIR

# get sync timestamp
# if none available, our best guess is the last timestamp from the point table
# it appears that osm2pgsql won't append duplicate changes
if [ ! -e $SYNC_DIR/sync_load.ts ]
then 
  psql -d osm_grid -At -c "select max(osm_timestamp) from planet_osm_point;" > $SYNC_DIR/sync_load.ts
fi

last_sync_timestamp=`cat $SYNC_DIR/sync_load.ts`

# get latest changesets
ruby sync_load.rb -g "$last_sync_timestamp" -c sync_load_cfg.rb 2> /dev/null > $SYNC_DIR/sync_load.log

# check whether output looks OK
if ! test $(wc -l $SYNC_DIR/sync_load.log | cut -f 1 -d ' ') = 1 && ! grep -Eq '[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}.*' $SYNC_DIR/sync_load.log
then
  echo "Failed to sync properly.  Check $SYNC_DIR/sync_load.log"
  exit 1
fi

cp $SYNC_DIR/sync_load.log $SYNC_DIR/sync_load.ts

# perform the update
ruby sync_load.rb -u -c sync_load_cfg.rb  
