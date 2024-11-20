#!/bin/bash

mongosh <<EOF_MONGO
use admin

rs.initiate(
  {
    _id: "config_rs",
    configsvr: true,
    members: [
      { _id : 1, host : "config-rides-prod-1:27017" },
      { _id : 2, host : "config-rides-prod-2:27017" },
      { _id : 3, host : "config-rides-prod-3:27017" }
    ]
  }
)

EOF_MONGO