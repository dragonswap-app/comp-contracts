#!/usr/bin/env bash

# Enable constructor-args
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

# Set RPC_URL based on the network
if [ "$NETWORK" == "mainnet" ]; then
    RPC_URL=$MAINNET_RPC_URL
else
    RPC_URL=$TESTNET_RPC_URL
fi

echo "Adjusting gas price..."
GAS_PRICE=$(cast gas-price --rpc-url $RPC_URL)
ADJUSTED_GAS_PRICE=$((GAS_PRICE * 120 / 100))  # Increase by 20%

# Add gas price to transaction command
TX_ARGS="--gas-price $ADJUSTED_GAS_PRICE"

# Deploy Factory contract
echo "Deploying Factory contract on ${NETWORK}..."
FACTORY_DEPLOY=$(forge create --rpc-url "$RPC_URL" \
    --private-key $PRIVATE_KEY \
    src/Factory.sol:Factory \
    --constructor-args $owner \
    $TX_ARGS \
    --json)

# Extract Factory address
FACTORY_ADDRESS=$(echo $FACTORY_DEPLOY | jq -r '.deployedTo')
echo "FACTORY_ADDRESS=$FACTORY_ADDRESS" >> $DEPLOYMENT_FILE

# Deploy Competition contract
echo "Deploying Competition contract on ${NETWORK}..."
COMPETITION_IMPLEMENTATION_DEPLOY=$(forge create --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY \
    src/Competition.sol:Competition \
    $TX_ARGS \
    --json)

# Extract Competition address
COMPETITION_IMPLEMENTATION_ADDRESS=$(echo $COMPETITION_IMPLEMENTATION_DEPLOY | jq -r '.deployedTo')
echo "COMPETITION_IMPLEMENTATION_ADDRESS=$COMPETITION_IMPLEMENTATION_ADDRESS" >> $DEPLOYMENT_FILE

echo "Deployment completed successfully on ${NETWORK}."
echo "Factory address: $FACTORY_ADDRESS"
echo "CompetitionImplementation address: $COMPETITION_IMPLEMENTATION_ADDRESS"

# Set Competition implementation in Factory
echo "Setting Competition implementation in Factory..."
SET_IMPLEMENTATION_RESULT=$(cast send --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY \
    $FACTORY_ADDRESS \
    "setImplementation(address)" \
    $COMPETITION_IMPLEMENTATION_ADDRESS \
    $TX_ARGS \
    --json)
    
# Confirm that correct competition address is set on Factory
echo "Confirming Competition implementation address in Factory..."
CONFIRMED_IMPLEMENTATION=$(cast call --rpc-url $RPC_URL $FACTORY_ADDRESS "implementation()(address)")
if [ "$CONFIRMED_IMPLEMENTATION" = "$COMPETITION_IMPLEMENTATION_ADDRESS" ]; then
    echo "Competition implementation address confirmed in Factory."
else
    echo "Error: Competition implementation address mismatch in Factory."
    echo "Expected: $COMPETITION_IMPLEMENTATION_ADDRESS"
    echo "Actual: $CONFIRMED_IMPLEMENTATION"
    exit 1
fi

