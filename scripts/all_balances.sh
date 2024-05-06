#!/usr/bin/bash
set -e
#
export CARDANO_NODE_SOCKET_PATH=$(cat ./data/path_to_socket.sh)
cli=$(cat ./data/path_to_cli.sh)
testnet_magic=$(cat ./data/testnet.magic)

# stake key
stake_key=$(jq -r '.stakeKey' ../config.json)

# perma lock ft contract
perma_lock_ft_script_path="../contracts/perma_lock_ft_contract.plutus"
perma_lock_ft_script_address=$(${cli} address build --payment-script-file ${perma_lock_ft_script_path} --stake-address ${stake_key} --testnet-magic ${testnet_magic})

# perma lock tkn contract
perma_lock_nft_script_path="../contracts/perma_lock_nft_contract.plutus"
perma_lock_nft_script_address=$(${cli} address build --payment-script-file ${perma_lock_nft_script_path} --stake-address ${stake_key} --testnet-magic ${testnet_magic})

${cli} query protocol-parameters --testnet-magic ${testnet_magic} --out-file ./tmp/protocol.json
${cli} query tip --testnet-magic ${testnet_magic} | jq
${cli} query tx-mempool info --testnet-magic ${testnet_magic} | jq

#
echo -e "\033[1;35m\nPerma Lock FT Script Address: \033[0m"
echo -e "\n \033[1;32m ${perma_lock_ft_script_address} \033[0m \n";
${cli} query utxo --address ${perma_lock_ft_script_address} --testnet-magic ${testnet_magic}

#
echo -e "\033[1;35m\nPerma Lock NFT Script Address: \033[0m"
echo -e "\n \033[1;32m ${perma_lock_nft_script_address} \033[0m \n";
${cli} query utxo --address ${perma_lock_nft_script_address} --testnet-magic ${testnet_magic}

# Loop through each -wallet folder
for wallet_folder in wallets/*-wallet; do
    # Check if payment.addr file exists in the folder
    if [ -f "${wallet_folder}/payment.addr" ]; then
        addr=$(cat ${wallet_folder}/payment.addr)
        echo
        
        echo -e "\033[1;37m --------------------------------------------------------------------------------\033[0m"
        echo -e "\033[1;37m --------------------------------------------------------------------------------\033[0m"
        echo -e "\033[1;34m $wallet_folder\033[0m\n\n\033[1;32m $addr\033[0m"
        

        echo -e "\033[1;33m"
        # Run the cardano-cli command with the reference address and testnet magic
        ${cli} query utxo --address ${addr} --testnet-magic ${testnet_magic}
        ${cli} query utxo --address ${addr} --testnet-magic ${testnet_magic} --out-file ./tmp/"${addr}.json"

        baseLovelace=$(jq '[.. | objects | .lovelace] | add' ./tmp/"${addr}.json")
        echo -e "\033[0m"

        echo -e "\033[1;36m"
        ada=$(echo "scale = 6;${baseLovelace} / 1000000" | bc -l)
        echo -e "TOTAL ADA:" ${ada}
        echo -e "\033[0m"
    fi
done