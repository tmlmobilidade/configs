#!/bin/bash

mongosh <<EOF_MONGO
use admin

// Create the admin user
db.createUser({
	user: "admin",
	pwd: "$HASHED_TRIPS_ADMIN_PASSWORD",
	roles: ["root"]
})

// Create a read-only user
db.createUser({
	user: "read",
	pwd: "$HASHED_TRIPS_READ_PASSWORD",
	roles: [ { role: "read", db: "production" } ]
})

// Create a read-write user
db.createUser({
	user: "write",
	pwd: "$HASHED_TRIPS_WRITE_PASSWORD",
	roles: [ { role: "readWrite", db: "production" } ]
})
EOF_MONGO
