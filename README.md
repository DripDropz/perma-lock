# Perma Lock

`Perma Lock` is a contract that permanently locks a specific token, allowing users to add tokens but preventing any withdrawals. Once tokens are locked in this contract, they can't be removed.

## **Prerequisites**
- Ensure you have `ADA` available for funding the wallets.
- Aiken, Python3, cardano-cli, jq, bc need to be installed for the happy path to function properly.

## **Configuration**

Begin by specifying the token details in `start_info.json`:

```json
{
  "__comment1__": "This is the locking token for the contract.",
  "lockingPid": "beec4fac1e41e603f4a8620d7864c1e2d55a2b9ae5522b675cfa6c52",
  "lockingTkn": "001bc280001af8787e4ae5450b462441e2f2626af48fd9faf1c500fbbf3d0737",
  "__comment2__": "This is maximum amount of the token in existence.",
  "maxTknAmt": 100000000
}
```

- The maximum allowed integer for `maxTknAmt` is $2^{63} - 1$.

## **Setup**


1. Execute the `complete_build.sh` script to prepare the environment.
   
2. Navigate to the `scripts` directory and create the necessary testnet wallets:

```bash
./create_testnet_wallet.sh wallets/reference-wallet
./create_testnet_wallet.sh wallets/collat-wallet
./create_testnet_wallet.sh wallets/user-wallet
```

3. Fund the wallets. The `user-wallet` will store the tokens you intend to add to the perma lock contract. The `collat-wallet` needs 5 ADA and the `reference-wallet` needs at least 10 ADA.

- The happy path assumes a synced testnet node. 
- Please update the `data/path_to_cli.sh` and `data/path_to_socket.sh` files to match your current `cardano-cli` and `node.socket` path.
- The `all_balances.sh` script will display the testnet wallet addresses and UTxOs.

## **Usage**

The `scripts` directory contains sequential scripts for a smooth execution. They facilitate:

- Setting up the reference wallet.
- Creating the perma-locked UTXO.
- Depositing tokens into the contract.

To add tokens to the contract:

```bash
./02_addTokens.sh 123456789
```

The command above locks 123,456,789 tokens into the contract, as specified in the `start_info.json`.

If the debug endpoint is set to `True` within the `perma.ak` script then the `debug.sh` script will allow a user to remove the perma locked utxo. This is for testing only and should be changed to `False` at production.

> ⚠️ **Caution**: This contract is designed to lock tokens irreversibly. Ensure you understand the implications before using.
