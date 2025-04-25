#!/bin/bash

set -e

# === CONFIGURATION ===

source ../.env

# === FUNCTIONS ===

pull_image() {
  echo "🚀 Pulling $CELESTIA_DOCKER_IMAGE image..."
  docker pull "$CELESTIA_DOCKER_IMAGE"
}

initialize_node() {
  echo "📁 Check existance of $CELESTIA_DATA_DIR/config.toml" 
  mkdir -p "$CELESTIA_DATA_DIR"
  if [ ! -f "$CELESTIA_DATA_DIR/config.toml" ]; then
    echo "🔧 Initializing $CELESTIA_NODE_TYPE node for $CELESTIA_NETWORK network..."
    docker run --rm \
      --user root \
      -v "$CELESTIA_DATA_DIR:/home/celestia" \
      "$CELESTIA_DOCKER_IMAGE" \
      /bin/celestia "$CELESTIA_NODE_TYPE" init --core.ip "$CELESTIA_NODE_CORE_IP" --p2p.network "$CELESTIA_NETWORK"
  else
    echo "✅ Node already initialized at $CELESTIA_DATA_DIR"
  fi
}

set_write_jwt() {
  echo "Exporting 'write' auth token "
  export CELESTIA_NODE_WRITE_TOKEN=$(docker run --rm \
    --user root \
    -v "$CELESTIA_DATA_DIR:/home/celestia" \
    "$CELESTIA_DOCKER_IMAGE" \
    /bin/celestia "$CELESTIA_NODE_TYPE" auth write)
  # Trim logs, only keep key
  CELESTIA_NODE_WRITE_TOKEN=$(echo "$CELESTIA_NODE_WRITE_TOKEN" | tail -n 1)
}

get_trusted_hash() {
  if [[ -z "$CELESTIA_TRUSTED_HASH" ]] || [[ -z "$CELESTIA_TRUSTED_HEIGHT" ]]; then
    local header_json
    header_json=$(curl -s "https://rpc-mocha.pops.one/header")
    export CELESTIA_TRUSTED_HEIGHT=$(echo "$header_json" | jq -r '.result.header.height')
    export CELESTIA_TRUSTED_HASH=$(echo "$header_json" | jq -r '.result.header.last_block_id.hash')
  else
    echo "CELESTIA_TRUSTED_HEIGHT=$CELESTIA_TRUSTED_HEIGHT"
    echo "CELESTIA_TRUSTED_HASH=$CELESTIA_TRUSTED_HASH"
  fi
}

# Unused here, but for reference:
run_node() {
  echo "🏃‍♂️ Starting $CELESTIA_NODE_TYPE node on $CELESTIA_NETWORK network..."
  docker run -d \
    --name "$CELESTIA_NODE_NAME" \
    -v "$CELESTIA_DATA_DIR:/home/celestia" \
    -p "$CELESTIA_P2P_PORT:$CELESTIA_P2P_PORT" \
    -p "$CELESTIA_RPC_PORT:$CELESTIA_RPC_PORT" \
    "$CELESTIA_DOCKER_IMAGE" \
    /bin/celestia "$CELESTIA_NODE_TYPE" start --core.ip "$CELESTIA_NODE_CORE_IP" --p2p.network "$CELESTIA_NETWORK"
}

# === MAIN EXECUTION ===

pull_image
initialize_node
set_write_jwt

echo -e "🎉 $CELESTIA_NODE_TYPE node for $CELESTIA_NETWORK network is ready with persistent storage at $CELESTIA_DATA_DIR\n\n"
echo    "CELESTIA_NODE_WRITE_TOKEN=$CELESTIA_NODE_WRITE_TOKEN"  
echo    "CELESTIA_TRUSTED_HEIGHT=$CELESTIA_TRUSTED_HEIGHT"
echo -e "CELESTIA_TRUSTED_HASH=$CELESTIA_TRUSTED_HASH\n"
echo    "^^^^ Remember to save these in '.env' to persist them!"

