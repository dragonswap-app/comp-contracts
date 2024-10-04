## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

Give the script the correct permissions and run it:

```shell
$ chmod +x script/deployFactory.sh
$ ./script/deployFactory.sh <network> # mainnet or testnet
```

```shell
$ chmod +x script/deployCompetition.sh
$ ./script/deployCompetition.sh <network> # mainnet or testnet
```

### Add Swap Tokens

```shell
$ chmod +x script/addSwapTokens.sh
$ ./script/addSwapTokens.sh <network> # mainnet or testnet
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
