# Perma Lock

`Perma Lock FT` is a contract that permanently locks a specific token known at compile time, allowing users to add tokens but preventing any withdrawals. Once tokens are locked in this contract, they can't be removed. This contract is great for fungible tokens because as it minimizes the minimum required Lovelace and forces the minimum required Lovelace to be constant. The transaction fees are nearly constant as it strongly depends on the number of UTxOs inside the transaction and not necessarily the computational units.

`Perma Lock NFT` is a contract that permanently locks any token, allowing users to add any token to the contract but prevents any withdrawals. Once tokens are locked in this contract, they can't be removed. This contract is great for non-fungible tokens and arbitrary tokens as any specific token can be added to the UTxO. The minimum required lovelace is not constant and is increased as needed during transaction creation. The transaction fees will always be increasing as it strongly depends on the number of tokens on the UTxO and the number of UTxOs inside the transaction.

## **Prerequisites**
- Ensure you have `ADA` available for funding the wallets.
- Aiken, Python3, cardano-cli, jq, bc need to be installed for the happy path to function properly.

## **Configuration**

Configuring the `Perma Lock FT` contract begins by specifying the token details inside `start_info.json`:

```json
{
  "__comment1__": "This is the ft to lock for the perma lock ft contract",
  "lockingPid": "954fe5769e9eb8dad54c99f8d62015c813c24f229a4d98dbf05c28b9",
  "lockingNFT": "546869735f49735f415f566572795f4c6f6e675f537472696e675f5f5f5f5f5f",
  "__comment2__": "This is maximum amount of the ft in existence.",
  "maxNFTAmt": 9223372036854775807
}
```

- The maximum allowed integer for `maxNFTAmt` is $2^{63} - 1$.

The `Perma Lock NFT` does not need to be configured.

## **Setup**

1. Execute the `complete_build.sh` script to prepare the environment.
   
2. Navigate to the `scripts` directory and create the necessary testnet wallets:

```bash
./create_testnet_wallet.sh wallets/reference-wallet
./create_testnet_wallet.sh wallets/collat-wallet
./create_testnet_wallet.sh wallets/user-wallet
```

3. Fund the wallets. The `user-wallet` will store the tokens you intend to add to the perma lock contracts. The `collat-wallet` needs 5 ADA and the `reference-wallet` needs at least 20 ADA.

4. Create the script references.

5. Change directory into either the `lock_ft` or `lock_nft`.

6. Create the perma locked UTxO required for the contract in use.


- The happy path assumes a synced testnet node. 
- Please update the `data/path_to_cli.sh` and `data/path_to_socket.sh` files to match your current `cardano-cli` and `node.socket` path.
- The `all_balances.sh` script will display the testnet wallet addresses and UTxOs.

## **Usage**

The `scripts` directory contains sequential scripts for a smooth execution. They facilitate:

- Setting up the reference wallet.
- Folders containing scripts for the perma-locked contracts.
- Depositing tokens into the contracts.

To add tokens to the `Perma Lock FT` contract:

```bash
./02_permaLockFT.sh 123456789
```

The command above locks 123,456,789 tokens into the contract, as specified in the `start_info.json`.

To add tokens to the `Perma Lock NFT` contract:

```bash
./02_permaLockNFT.sh $policy_id $token_name $amount
```

The command above locks some amount of tokens into the contract, as specified by the `policy_id` and `token_name`.

> ⚠️ **Caution**: This contract is designed to lock tokens irreversibly. Ensure you understand the implications before using.
