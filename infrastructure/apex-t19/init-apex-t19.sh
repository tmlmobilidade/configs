#!/bin/bash

mongosh <<EOF_MONGO
use admin

// Create the admin user
db.createUser({
	user: "admin",
	pwd: "$APEX_T19_ADMIN_PASSWORD",
	roles: ["root"]
})

// Create a read-only user
db.createUser({
	user: "read",
	pwd: "$APEX_T19_READ_PASSWORD",
	roles: [ { role: "read", db: "production" } ]
})

// Create a read-write user
db.createUser({
	user: "write",
	pwd: "$APEX_T19_WRITE_PASSWORD",
	roles: [ { role: "readWrite", db: "production" } ]
})
EOF_MONGO
