## Trading Competition

This Trading Competition is a decentralized platform that allows participants to engage in competitive trading activities on the Dragonswap. It leverages smart contracts to create a fair and transparent environment where traders can showcase their skills and compete for rewards. The competition runs for a specified duration, utilizing designated swap tokens and stablecoins for trading activities. Participants' performance is tracked and evaluated based on their trading strategies and outcomes.

Key features:
- Time-bound competition with predefined start and end timestamps
- Integration with a specified router for executing trades
- Utilization of two stablecoins for price stability and comparison
- Support for multiple swap tokens to diversify trading options
- Transparent and immutable rules enforced by smart contracts
- Automated performance tracking and ranking system

The competition aims to foster innovation in trading strategies and reward skilled traders in a decentralized manner.


### Deploy


#### Deploy Factory
To deploy factory follow these steps:

1. Make sure you have a `.env` file with your `PRIVATE_KEY` set.
2. Make sure you have correct values in `config.json` file for the following fields:

```json
    {
      "owner": "0x...",
      "network": "mainnet" or "testnet",
      "testnetRpcUrl": "https://...",
      "mainnetRpcUrl": "https://..."
    }
```

##### Using Foundry:

```shell
$ forge script script/DeployFactory.s.sol:DeployFactoryScript --broadcast
```

##### Using shell scripts:

Give the script the correct permissions and run it:

```shell
$ chmod +x script/deployFactory.sh
$ ./script/deployFactory.sh <network> # mainnet or testnet
```

#### Deploy Competition

To deploy competition follow these steps:

1. Make sure you have a `.env` file with your `PRIVATE_KEY` set.
2. Make sure you have correct values in `config.json` file for the following fields:

```json
    {
      "factoryAddress": "0x...",
      "startTimestamp": 1234567890,
      "endTimestamp": 1234567890,
      "router": "0x...",
      "stable0": "0x...",
      "stable1": "0x...",
      "swapTokens": ["0x...", "0x..."],
      "network": "mainnet" or "testnet",
      "testnetRpcUrl": "https://...",
      "mainnetRpcUrl": "https://..."
    }
```

##### Using Foundry:

```shell
$ forge script script/Competition.s.sol:DeployCompetitionScript --broadcast
```

##### Using shell scripts:

Give the script the correct permissions and run it:

```shell
$ chmod +x script/deployCompetition.sh
$ ./script/deployCompetition.sh <network> # mainnet or testnet
```

### Add Swap Tokens

In order to add swap tokens to an existing Competition, you need to setup the following:

1. Make sure you have a `.env` file with your `PRIVATE_KEY` set.
2. Make sure you have a `config.json` file with the following fields:

```json
    {
      "competitionAddress": "0x...",
      "swapTokens": ["0x...", "0x..."],
      "network": "mainnet" or "testnet",
      "testnetRpcUrl": "https://...",
      "mainnetRpcUrl": "https://..."
    }
```

Using Foundry:

Run the script:

```shell
$ forge script script/AddSwapTokens.s.sol:AddSwapTokensScript --broadcast
```

Using shell scripts:

```shell
$ chmod +x script/addSwapTokens.sh
$ ./script/addSwapTokens.sh <network> # mainnet or testnet
```