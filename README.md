# Merkle Airdrop

This repository contains an advanced Solidity airdrop contract developed with Foundry, showcasing modern best practices such as Merkle proofs, EIP-712 signatures (meta-transactions), on-chain eligibility gating, tiered distributions, time-based expiry, batching, and emergency controls.

This contract extends a basic Merkle airdrop into a fully production-grade, gas-efficient, and flexible distribution module.

[Merkle Airdrop V2 sepolia](https://sepolia.etherscan.io/address/0x091ea0838ebd5b7dda2f2a641b068d6d59639b98#code)

# About

## MerkleAirdropV2 
 - is an advanced token airdrop mechanism featuring:

### Tiered token allocations

Each address may receive a different amount, encoded inside the Merkle tree.

### Optional on-chain footprint gating

Restrict eligibility using minimum ETH balance and/or minimum transaction count (nonce). This allows Sybil-resistance extensions.

### EIP-712 meta-transactions (gasless claims)

A relayer can submit the claim on behalf of a user with their signed message.

### Claim window with expiry

Owner can configure a timestamp after which claims are rejected.

### Batch claims

Efficiently sweep multiple claims in one transaction.

### Clawback / token recovery

When the claim window expires, the owner can recover leftover tokens.

### Emergency pause switch

Pause claim operations during emergencies.

### Indexed claim events

Optimized logs for indexing, subgraphs, and analytics.

# Table of Contents

- [Merkle Airdrop](#Merkle-Airdrop)
- [About](#about)
- [Getting Started](#getting-started)
  - [Requirements](#requirements)
  - [Quickstart](#quickstart)
- [Usage](#usage)
  - [Start a local node](#start-a-local-node)
  - [Deploy](#deploy)
  - [Deploy - Other Network](#deploy---other-network)
  - [Testing](#testing)
    - [Test Coverage](#test-coverage)
- [Deployment to a testnet or mainnet](#deployment-to-a-testnet-or-mainnet)
  - [Scripts](#scripts)
  - [Estimate gas](#estimate-gas)
- [Admin Functions](#Admin-functions)
- [Formatting](#formatting)
- [Slither](#slither)
- [Additional Info:](#additional-info)
- [Thank you!](#thank-you)

# Getting Started

## Requirements

- [git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
  - You'll know you did it right if you can run `git --version` and you see a response like `git version x.x.x`
- [foundry](https://getfoundry.sh/)
  - You'll know you did it right if you can run `forge --version` and you see a response like `forge 0.2.0 (816e00b 2023-03-16T00:05:26.396218Z)`

## Quickstart

```
git clone https://github.com/USII-004/foundry-merkle-airdrop.git
cd foundry-merkle-airdrop
forge build
```

# Usage

## Start a local node

```
make anvil
```

## Deploy

This will default to your local node. You need to have it running in another terminal in order for it to deploy.

```
make deploy
```

## Deploy - Other Network

[See below](#deployment-to-a-testnet-or-mainnet)

## Testing

```
forge test
```

### Test Coverage

```
forge coverage
```

and for coverage based testing:

```
forge coverage --report debug
```

# Deployment to a testnet or mainnet

1. Setup environment variables

You'll want to set your `SEPOLIA_RPC_URL` and `PRIVATE_KEY` as environment variables. You can add them to a `.env` file, similar to what you see in `.env.example`.

- `PRIVATE_KEY`: The private key of your account (like from [metamask](https://metamask.io/)). **NOTE:** FOR DEVELOPMENT, PLEASE USE A KEY THAT DOESN'T HAVE ANY REAL FUNDS ASSOCIATED WITH IT.
  - You can [learn how to export it here](https://metamask.zendesk.com/hc/en-us/articles/360015289632-How-to-Export-an-Account-Private-Key).
- `SEPOLIA_RPC_URL`: This is url of the sepolia testnet node you're working with. You can get setup with one for free from [Alchemy](https://alchemy.com/?a=673c802981)

Optionally, add your `ETHERSCAN_API_KEY` if you want to verify your contract on [Etherscan](https://etherscan.io/).

1. Get testnet ETH

Head over to [faucets.chain.link](https://faucets.chain.link/) and get some testnet ETH. You should see the ETH show up in your metamask.

2. Deploy

```
make deploy ARGS="--network sepolia"
```

## Scripts

Instead of scripts, we can directly use the `cast` command to interact with the contract.

For example, on Sepolia:

1. Set claim deadline

```
cast send <CONTRACT> "setClaimDeadline(uint256)" 1700000000 \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY
```

2. Set footprint requirement

```
cast send <CONTRACT> "setFootprintRequirement(uint256,uint64)" \
  100000000000000000 10 \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY
```

3. Pause \ Unpause

```
cast send <CONTRACT> "pause()" --rpc-url $RPC_URL --private-key $PRIVATE_KEY
cast send <CONTRACT> "unpause()" --rpc-url $RPC_URL --private-key $PRIVATE_KEY
```

4. Recover tokens after expiry

```
cast send <CONTRACT> "recoverTokens(address)" <recipient> \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY

```

## Estimate gas

You can estimate how much gas things cost by running:

```
forge snapshot
```

And you'll see an output file called `.gas-snapshot`

# Admin Functions

The following functions are restricted by `onlyOwner`

| Function                                  | Purpose                               |
| ----------------------------------------- | ------------------------------------- |
| `setClaimDeadline(uint256)`               | Set or remove claim expiry            |
| `setFootprintRequirement(uint256,uint64)` | Configure eligibility filters         |
| `pause()`                                 | Pause all claim operations            |
| `unpause()`                               | Resume claims                         |
| `recoverTokens(address)`                  | Recover unclaimed tokens after expiry |
| `transferOwnership(address)`              | Assign new owner                      |

You must call these functions using the wallet that deployed the contract (unless ownership was transferred).

# Formatting

To run code formatting:

```
forge fmt
```

# Slither

```
slither :; slither . --config-file slither.config.json
```

# Additional Info:
The contract is built using battle-tested OpenZeppelin libraries (ERC20, EIP-712, MerkleProof, Ownable, Pausable, ReentrancyGuard).

# Thank you!

If you found this helpful, feel free to ⭐ star the repo or follow for more Solidity content!