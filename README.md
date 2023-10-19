# Perma Lock

This contract perma locks a token forever, allowing the user to add tokens but never remove them. This contract is compiled to a specific token.

## Set up

Define the token information in the `start_info.json`

```json
{
  "__comment1__": "This is the locking token for the contract",
  "lockingPid": "beec4fac1e41e603f4a8620d7864c1e2d55a2b9ae5522b675cfa6c52",
  "lockingTkn": "001bc280001af8787e4ae5450b462441e2f2626af48fd9faf1c500fbbf3d0737",
  "maxTknAmt": 100000000
}
```

Run the `complete_build.sh` script.

Enter the scripts folder and create the required testnet wallets.

```bash
./create_testnet_wallet.sh wallets/reference-wallet
./create_testnet_wallet.sh wallets/collat-wallet
./create_testnet_wallet.sh wallets/user-wallet
```

Fund the wallets with some ada. The user wallet will hold the tokens to add to the perma lock.

## Usage

The `scripts` folder has sequential scripts for the happy path. They will allow setting up the reference wallet, creating the perma-locked utxo, and adding tokens to the contract.

A user can add tokens to the contract with the command below.

```bash
./02_addTokens.sh 123456789
```

This will lock 123,456,789 tokens into the contract where the token is defined in the `start_info.json` file.

* This contract is designed to permanently lock tokens forever.