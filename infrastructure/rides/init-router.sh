#!/bin/bash

mongosh <<EOF_MONGO
use admin

sh.addShard("shard1_rs/cluster-rides-shard-1.cmet.pt:27017")
sh.addShard("shard2_rs/cluster-rides-shard-2.cmet.pt:20004")

use production

sh.enableSharding("production")

sh.shardCollection("production.rides", { operational_day: 1 } )

EOF_MONGO