#!/bin/bash

mongosh <<EOF_MONGO
use admin

rs.initiate(
  {
    _id: "shard1_rs",
    members: [
      { _id : 1, host : "localhost:27017" },
    ]
  }
)

EOF_MONGO