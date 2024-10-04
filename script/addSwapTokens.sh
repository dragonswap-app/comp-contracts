#!/usr/bin/env bash

# Enable error handling
set -e

REPO_BASE_PATH=$(
  cd "$(dirname "${BASH_SOURCE[0]}")"
  cd .. && pwd
)

source $REPO_BASE_PATH/.env
source $REPO_BASE_PATH/config

# Check if network parameter is provided
if [ "$1" != "mainnet" ] && [ "$1" != "testnet" ]; then
    echo "Please specify 'mainnet' or 'testnet' as the first argument."
    exit 1
fi

NETWORK=$1
NETWORK_UPPER=$(echo "$NETWORK" | tr '[:lower:]' '[:upper:]')
DEPLOYMENT_FILE="$REPO_BASE_PATH/deployment_${NETWORK}"

# Load addresses from deployment file
source $DEPLOYMENT_FILE

# Set RPC_URL based on the network
if [ "$NETWORK" == "mainnet" ]; then
    RPC_URL=$MAINNET_RPC_URL
else
    RPC_URL=$TESTNET_RPC_URL
fi

# Check gas price
GAS_PRICE=$(cast gas-price --rpc-url $RPC_URL)
ADJUSTED_GAS_PRICE=$((GAS_PRICE * 120 / 100))  # Increase by 20%

# Add gas price to transaction command
TX_ARGS="--gas-price $ADJUSTED_GAS_PRICE"

# Add swap tokens to the Competition
echo "Adding swap tokens to Competition on ${NETWORK}..."
TX_RESULT=$(cast send --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY \
    $COMPETITION_ADDRESS \
    "addSwapTokens(address[])" \
    "[$swapTokens]" \
    $TX_ARGS \
    --json)

# Extract transaction hash
TX_HASH=$(echo $TX_RESULT | jq -r '.transactionHash')
echo "Add swap tokens transaction hash: $TX_HASH"

echo "Swap tokens added successfully to Competition on ${NETWORK}."
