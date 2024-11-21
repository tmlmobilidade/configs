#!/bin/sh

# # # # # # # # # # # # # # # # # # # # # # # # # # # # 
# # # # # # # # # # # # # # # # # # # # # # # # # # # # 

# Title section
echo "================================"
echo "   TML Single Instance Setup    "
echo "================================"

# Prompt for service name and port
read -p "Enter the service name: " SERVICE_NAME
read -p "Enter the port: " PORT

mkdir -p $SERVICE_NAME
cd $SERVICE_NAME

# Convert service name to uppercase for variable prefix
SERVICE_PREFIX=$(echo "$SERVICE_NAME" | tr '[:lower:]' '[:upper:]')

# # # # # # # # # # # # # # # # # # # # # # # # # # # # 
# # # # # # # # # # # # # # # # # # # # # # # # # # # # 

# Define allowed characters for passwords (excluding !, ", #, $, /, and =)
ALLOWED_CHARACTERS="0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz&%"

# Function to generate a random password of given length
generate_password() {
    local length=$1
    local password=""
    for i in $(seq 1 $length); do
        # Generate a random index based on the length of ALLOWED_CHARACTERS
        local index=$((RANDOM % ${#ALLOWED_CHARACTERS}))
        # Append the character at the random index to the password
        password="${password}${ALLOWED_CHARACTERS:$index:1}"
    done
    echo "$password"
}

# Generate random passwords with service-specific prefixes
ADMIN_PASSWORD=$(generate_password 12)
READ_PASSWORD=$(generate_password 12)
WRITE_PASSWORD=$(generate_password 12)

# # # # # # # # # # # # # # # # # # # # # # # # # # # # 
# # # # # # # # # # # # # # # # # # # # # # # # # # # # 

# Substitute variables and save as a new compose file
# sed -e "s|\${SERVICE_NAME}|$SERVICE_NAME|g" \
#     -e "s|\${PORT}|$PORT|g" \
#     -e "s|\${MONGO_INITDB_ROOT_USERNAME}|admin|g" \
#     -e "s|\${MONGO_INITDB_ROOT_PASSWORD}|$ADMIN_PASSWORD|g" \
#     compose.yaml.template > compose.yaml
cat <<EOF > compose.yaml
name: ${SERVICE_NAME}

secrets:
  backupd_config:
    file: ./backupd.yaml

services:
 #

  # # # # # # # # # # # # # # # # # # # # #
  # # # # # # # # # # # # # # # # # # # # #

  watchtower:
    image: containrrr/watchtower
    command: --interval 30 --scope ${SERVICE_NAME}
    deploy:
      restart_policy:
        condition: on-failure
        delay: 30s
      resources:
        limits:
          memory: 100mb
    logging:
      options:
        max-size: '1m'
        max-file: '1'
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - WATCHTOWER_POLL_INTERVAL=10
      - WATCHTOWER_CLEANUP=TRUE
      - WATCHTOWER_INCLUDE_STOPPED=TRUE
      - WATCHTOWER_REVIVE_STOPPED=TRUE
      - WATCHTOWER_ROLLING_RESTART=TRUE
    labels: ["com.centurylinklabs.watchtower.scope=${SERVICE_NAME}"]

  # # # # # # # # # # # # # # # # # # # # #
  # # # # # # # # # # # # # # # # # # # # #

  ${SERVICE_NAME}_db:
    image: mongo:latest
    ports:
      - ${PORT}:27017
    volumes:
      - ./init-mongo.sh:/docker-entrypoint-initdb.d/init-mongo.sh
      - ./${SERVICE_NAME}_db_data:/data/db
    labels: ["com.centurylinklabs.watchtower.scope=${SERVICE_NAME}"]
    environment:
      - MONGO_INITDB_ROOT_USERNAME=admin
      - MONGO_INITDB_ROOT_PASSWORD=${ADMIN_PASSWORD}
    healthcheck:
      test: ["CMD", "mongo", "--eval", "db.runCommand('ping').ok"]
      interval: 1m30s
      timeout: 30s
      retries: 5

  # # # # # # # # # # # # # # # # # # # # #

  backupd:
    image: ghcr.io/tmlmobilidade/backupd:production
    secrets:
      - backupd_config
EOF

# Export dynamic environment variables
export "${SERVICE_PREFIX}_SERVICE_NAME=$SERVICE_NAME"
export "${SERVICE_PREFIX}_PORT=$PORT"
export "${SERVICE_PREFIX}_ADMIN_USERNAME=admin"
export "${SERVICE_PREFIX}_ADMIN_PASSWORD=$ADMIN_PASSWORD"
export "${SERVICE_PREFIX}_READ_USERNAME=read"
export "${SERVICE_PREFIX}_READ_PASSWORD=$READ_PASSWORD"
export "${SERVICE_PREFIX}_WRITE_USERNAME=write"
export "${SERVICE_PREFIX}_WRITE_PASSWORD=$WRITE_PASSWORD"

echo "Environment variables set:"
echo "  ${SERVICE_PREFIX}_ADMIN_USERNAME: admin"
echo "  ${SERVICE_PREFIX}_ADMIN_PASSWORD: $ADMIN_PASSWORD"
echo "  ${SERVICE_PREFIX}_READ_USERNAME: read"
echo "  ${SERVICE_PREFIX}_READ_PASSWORD: $READ_PASSWORD"
echo "  ${SERVICE_PREFIX}_WRITE_USERNAME: write"
echo "  ${SERVICE_PREFIX}_WRITE_PASSWORD: $WRITE_PASSWORD"

# # # # # # # # # # # # # # # # # # # # # # # # # # # # 
# # # # # # # # # # # # # # # # # # # # # # # # # # # # 

# Generate init-mongo.sh file
cat <<EOF > init-mongo.sh
#!/bin/bash

mongosh <<EOF_MONGO
use admin

// Create the admin user
db.createUser({
  user: "admin",
  pwd: "${ADMIN_PASSWORD}",
  roles: [ { role: "root", db: "admin" } ]
})

// Create a read-only user
db.createUser({
  user: "read",
  pwd: "${READ_PASSWORD}",
  roles: [ { role: "read", db: "admin" } ]
})

// Create a read-write user
db.createUser({
  user: "write",
  pwd: "${WRITE_PASSWORD}",
  roles: [ { role: "readWrite", db: "admin" } ]
})
EOF_MONGO
EOF

# Make the init-mongo.sh file executable
chmod +x init-mongo.sh

# # # # # # # # # # # # # # # # # # # # # # # # # # # # 
# # # # # # # # # # # # # # # # # # # # # # # # # # # # 

cd ..