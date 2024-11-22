#!/bin/bash

# # # # # # # # # # # # # # # # # # # # # # # # # # # #
#                      CONSTANTS                      #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # 
ALPHABET_LOWER="abcdefghijklmnopqrstuvwxyz"

# # # # # # # # # # # # # # # # # # # # # # # # # # # #
#                      FUNCTIONS                      #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # 

prompt_for_value() {
  local VAR_NAME=$1
  local MIN=$2
  local MAX=$3
  local SELECTED_VALUE=""

  while :; do
      read -p "Enter the number of $VAR_NAME ($MIN-$MAX): " SELECTED_VALUE
      if [ "$SELECTED_VALUE" -ge $MIN ] && [ "$SELECTED_VALUE" -le $MAX ]; then
      break
    else
      echo "Please enter a valid number between $MIN and $MAX."
    fi
  done

  echo $SELECTED_VALUE
}

wait_for() {
  local MESSAGE=$1
  SECONDS=$2
  for seconds in $(seq $SECONDS -1 1); do
    printf "\rWaiting %d seconds for $MESSAGE..." "$seconds"
    sleep 1
  done
  printf "\n"
}

replica_letter() {
  local REPLICA_NUMBER=$1
  echo "${ALPHABET_LOWER:$((REPLICA_NUMBER-1)):1}"
}

docker_service_watchtower() {
  local SERVICE_NAME=$1
  cat <<EOF
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
    labels:
      - "com.centurylinklabs.watchtower.scope=${SERVICE_NAME}"
EOF
}

docker_service_backup() {
  local SERVICE_NAME=$1
  cat <<EOF
  backupd:
    image: ghcr.io/tmlmobilidade/backupd:production
    secrets:
      - backupd_config
EOF
}

docker_service_config() {
  local SERVICE_NAME=$1
  local TOTAL_REPLICAS=$2

  for REPLICA_NUMBER in $(seq 1 "$TOTAL_REPLICAS"); do
    cat <<EOF
  config-${SERVICE_NAME}-$(replica_letter "$REPLICA_NUMBER"):
    image: mongo:latest
    container_name: config-${SERVICE_NAME}-$(replica_letter "$REPLICA_NUMBER")
    command: mongod --configsvr --replSet rs-config-server --port 27017 --dbpath /data/db
    restart: always
    ports:
      - "3700${REPLICA_NUMBER}:27017"
    volumes:
      - config-${SERVICE_NAME}-$(replica_letter "$REPLICA_NUMBER")-data:/data/db
    networks:
      - sharding
EOF

    if [ "$REPLICA_NUMBER" -eq 1 ]; then
      cat <<EOF
    depends_on:
EOF
      for NEXT_REPLICA_NUMBER in $(seq "$((REPLICA_NUMBER + 1))" "$TOTAL_REPLICAS"); do
        cat <<EOF
      - config-${SERVICE_NAME}-$(replica_letter "$NEXT_REPLICA_NUMBER")
EOF
      done
    fi
  done
}

docker_service_init_config() {
  local SERVICE_NAME=$1
  local TOTAL_REPLICAS=$2

  cat <<EOF
  init-config:
    image: mongo:latest
    entrypoint: [ "sh", "-c", "chmod +x /data/init.sh && /data/init.sh" ]
    restart: "no"
    volumes:
      - ./init-config.sh:/data/init.sh
    networks:
      - sharding
    depends_on:
EOF
  for REPLICA_NUMBER in $(seq 1 "$TOTAL_REPLICAS"); do
    cat <<EOF
      - config-${SERVICE_NAME}-$(replica_letter "$REPLICA_NUMBER")
EOF
  done
}

docker_service_router() {
  local SERVICE_NAME=$1
  local TOTAL_REPLICAS=$2

  cat <<EOF
  router-${SERVICE_NAME}:
    image: mongo:latest
    container_name: router-${SERVICE_NAME}
    command: mongos --configdb rs-config-server/config-${SERVICE_NAME}-a:27017,config-${SERVICE_NAME}-b:27017,config-${SERVICE_NAME}-b:27017  --bind_ip_all
    restart: always
    ports:
      - "27017:27017"
    volumes:
      - router-${SERVICE_NAME}-data:/data/db
    networks:
      - sharding

  init-router:
    image: mongo:latest
    entrypoint: [ "sh", "-c", "chmod +x /data/init.sh && /data/init.sh" ]
    restart: "no"
    networks:
      - sharding
    volumes:
      - ./init-router.sh:/data/init.sh
    depends_on:
      - router-${SERVICE_NAME}
EOF
  for REPLICA_NUMBER in $(seq 1 "$TOTAL_REPLICAS"); do
    cat <<EOF
      - config-${SERVICE_NAME}-$(replica_letter "$REPLICA_NUMBER")
EOF
  done
}

docker_service_shard() {
  local SERVICE_NAME=$1
  local REPLICA_NUMBER=$2
  local SHARD_NUMBER=$3

  cat <<EOF
  shardsvr-${SHARD_NUMBER}-${SERVICE_NAME}-$(replica_letter "$REPLICA_NUMBER"):
    image: mongo:latest
    container_name: shardsvr-${SHARD_NUMBER}-${SERVICE_NAME}-$(replica_letter "$REPLICA_NUMBER")
    command: mongod --shardsvr --replSet rs-shard-${SHARD_NUMBER} --port 27017 --dbpath /data/db
    restart: always
    ports:
      - "37${SHARD_NUMBER}0${REPLICA_NUMBER}:27017"
    volumes:
      - shardsvr-${SHARD_NUMBER}-${SERVICE_NAME}-$(replica_letter "$REPLICA_NUMBER")-data:/data/db
    networks:
      - sharding

EOF
  if [ $REPLICA_NUMBER -eq 1 ]; then
    cat <<EOF
  init-shard-${SHARD_NUMBER}-${SERVICE_NAME}:
    image: mongo:latest
    entrypoint: [ "sh", "-c", "chmod +x /data/init.sh && /data/init.sh" ]
    restart: "no"
    volumes:
      - ./init-shard.sh:/data/init.sh
    networks:
      - sharding
    depends_on:
      - shardsvr-${SHARD_NUMBER}-${SERVICE_NAME}-$(replica_letter "$REPLICA_NUMBER")
EOF
  fi
}

script_init_config() {
  local SERVICE_NAME=$1
  local TOTAL_REPLICAS=$2

  cat <<EOF
#!/bin/bash

sleep 5

# Initiate the replica set
mongosh --host config-${SERVICE_NAME}-a:27017 <<EOF_MONGO
rs.initiate({
  _id: "rs-config-server",
  configsvr: true,
  members: [
EOF
  for REPLICA_NUMBER in $(seq 1 "$TOTAL_REPLICAS"); do
    cat <<EOF
    { _id: $((REPLICA_NUMBER - 1)), host: "config-${SERVICE_NAME}-$(replica_letter "$REPLICA_NUMBER"):27017" },
EOF
  done
  cat <<EOF
  ]
});
EOF_MONGO

# Wait for mongod process to keep the container running
wait \$MONGOD_PID
EOF
}

script_init_router() {
  local SERVICE_NAME=$1
  local TOTAL_REPLICAS=$2
  local TOTAL_SHARDS=$3

  cat <<EOF
#!/bin/bash

sleep 20

mongosh --host router-${SERVICE_NAME}:27017 <<EOF_MONGO
EOF
  for SHARD_NUMBER in $(seq 1 "$TOTAL_SHARDS"); do
    for REPLICA_NUMBER in $(seq 1 "$TOTAL_REPLICAS"); do
      cat <<EOF
sh.addShard("rs-shard-${SHARD_NUMBER}/shardsvr-${SHARD_NUMBER}-${SERVICE_NAME}-$(replica_letter "$REPLICA_NUMBER")")
EOF
    done
  done
  cat <<EOF
sh.enableSharding("production")

EOF_MONGO

# Wait for mongod process to keep the container running
wait \$MONGOD_PID
EOF
}

script_init_shard() {
  local SERVICE_NAME=$1
  local TOTAL_REPLICAS=$2
  local SHARD_NUMBER=$3

  cat <<EOF
#!/bin/bash

sleep 5

# Initiate the replica set
mongosh --host shardsvr-${SHARD_NUMBER}-${SERVICE_NAME}-a:27017 <<EOF_MONGO
rs.initiate({
  _id: "rs-shard-${SHARD_NUMBER}",
  members: [
EOF
  for REPLICA_NUMBER in $(seq 1 "$TOTAL_REPLICAS"); do
    cat <<EOF
    { _id: $((REPLICA_NUMBER - 1)), host: "shardsvr-${SHARD_NUMBER}-${SERVICE_NAME}-$(replica_letter "$REPLICA_NUMBER"):27017" },
EOF
  done
  cat <<EOF
  ]
});
EOF_MONGO

# Wait for mongod process to keep the container running
wait \$MONGOD_PID
EOF
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # #
#                  PROMPT USER INPUT                  #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # 

echo "\n"
echo "+-----------------------------------------------+"
echo "|          TML SHARDING INSTANCE SETUP          |"
echo "+-----------------------------------------------+"
echo "\n"

read -p "Enter the service name: " SERVICE_NAME
NUM_SHARDS=$(prompt_for_value "shards" 1 5)
NUM_READ_REPLICAS=$(prompt_for_value "read replicas" 1 5)

RUN_LOCALLY=""
while true; do
  read -p "Run All Locally (For Testing Purposes)? (y/n): " RUN_LOCALLY
  case $RUN_LOCALLY in
    y|Y) break ;;
    n|N) break ;;
    *) echo "Please enter a valid option (y/n)." ;;
  esac
done

# # # # # # # # # # # # # # # # # # # # # # # # # # # #
#                  BUILD DIRECTORIES                  #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # 
mkdir -p $SERVICE_NAME
cd $SERVICE_NAME

mkdir -p 0-router-config

for i in $(seq 1 $NUM_SHARDS); do
  for j in $(seq 1 $NUM_READ_REPLICAS); do
    mkdir -p $i-${SERVICE_NAME}-$(replica_letter "$j")
  done
done

# # # # # # # # # # # # # # # # # # # # # # # # # # # #
#              Router & Config Servers                #
# # # # # # # # # # # # # # # # # # # # # # # # # # # #

# ===== Generate scripts =====
script_init_config $SERVICE_NAME 3 > 0-router-config/init-config.sh
script_init_router $SERVICE_NAME $NUM_READ_REPLICAS $NUM_SHARDS > 0-router-config/init-router.sh

# ===== Generate docker-compose.yaml =====

cat <<EOF > 0-router-config/docker-compose.yaml
name: tml-cluster-${SERVICE_NAME}

networks:
  sharding:
    name: cluster-${SERVICE_NAME}-network
    driver: bridge

volumes:
  router-${SERVICE_NAME}-data:
EOF
  for j in $(seq 1 3); do
    cat <<EOF >> 0-router-config/docker-compose.yaml
  config-${SERVICE_NAME}-$(replica_letter "$j")-data:
EOF
  done
cat <<EOF >> 0-router-config/docker-compose.yaml

services:
$(docker_service_config $SERVICE_NAME 3)

$(docker_service_init_config $SERVICE_NAME 3)

$(docker_service_router $SERVICE_NAME $NUM_READ_REPLICAS $NUM_SHARDS)
EOF

# # # # # # # # # # # # # # # # # # # # # # # # # # # #
#                   Shards Servers                    #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # 

# ===== Generate scripts =====
for i in $(seq 1 $NUM_SHARDS); do
  for j in $(seq 1 $NUM_READ_REPLICAS); do
    if [ $j -eq 1 ]; then
      script_init_shard $SERVICE_NAME $NUM_READ_REPLICAS $i > $i-${SERVICE_NAME}-$(replica_letter "$j")/init-shard.sh
    fi
  done
done

# ===== Generate docker-compose.yaml =====
for i in $(seq 1 $NUM_SHARDS); do
  for j in $(seq 1 $NUM_READ_REPLICAS); do
    cat <<EOF >> $i-${SERVICE_NAME}-$(replica_letter "$j")/docker-compose.yaml
name: tml-cluster-${SERVICE_NAME}-shard-${i}-$(replica_letter "$j")

networks:
  sharding:
    name: cluster-${SERVICE_NAME}-network
    driver: bridge

volumes:
  shardsvr-${i}-${SERVICE_NAME}-$(replica_letter "$j")-data:

services:
$(docker_service_shard $SERVICE_NAME $j $i)
EOF
  done
done

# # # # # # # # # # # # # # # # # # # # # # # # # # # #
#                   Setup environment                 #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # 

if [ "$RUN_LOCALLY" != "y" ]; then
  exit 0
fi

# Run docker compose for shards
for i in $(seq $NUM_SHARDS -1 1); do
  for j in $(seq $NUM_READ_REPLICAS -1 1); do
    docker compose -f $i-${SERVICE_NAME}-${ALPHABET_LOWER:$((j-1)):1}/docker-compose.yaml up -d
  done
done

wait_for "shards to initialize" 5

docker compose -f 0-router-config/docker-compose.yaml up -d