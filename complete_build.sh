#!/bin/bash
set -e

# create directories if dont exist
mkdir -p contracts
mkdir -p hashes

# remove old files
rm contracts/* || true
rm hashes/* || true
rm -fr build/ || true

# build out the entire script
echo -e "\033[1;34m\nBuilding Contracts\n\033[0m"

# standard build
aiken build

# keep the traces for testing if required
# aiken build --keep-traces

###############################################################################
###############################################################################
###############################################################################

# build out the entire script
echo -e "\033[1;34m\nBuilding FT Contract \033[0m"

# the locking token information
locking_pid=$(jq -r '.lockingPid' start_info.json)
locking_tkn=$(jq -r '.lockingTkn' start_info.json)

# one liner for correct cbor
# requires cbor2
locking_pid_cbor=$(python3 -c "import cbor2;hex_string='${locking_pid}';data = bytes.fromhex(hex_string);encoded = cbor2.dumps(data);print(encoded.hex())")
locking_tkn_cbor=$(python3 -c "import cbor2;hex_string='${locking_tkn}';data = bytes.fromhex(hex_string);encoded = cbor2.dumps(data);print(encoded.hex())")

echo -e "\033[1;33m Convert Perma Lock FT Contract \033[0m"

aiken blueprint apply -o plutus.json -v perma_lock_ft.params "${locking_pid_cbor}"
aiken blueprint apply -o plutus.json -v perma_lock_ft.params "${locking_tkn_cbor}"
aiken blueprint convert -v perma_lock_ft.params > contracts/perma_lock_ft_contract.plutus

###############################################################################
###############################################################################
###############################################################################

echo -e "\033[1;34m\nBuilding FT Contract \033[0m"
echo -e "\033[1;33m Convert Perma Lock Tkn Contract \033[0m"

aiken blueprint convert -v perma_lock_tkn.params > contracts/perma_lock_tkn_contract.plutus

###############################################################################
###############################################################################
###############################################################################

# store the script hash
echo -e "\033[1;34m\nBuilding Contract Hash Data \033[0m"

cardano-cli transaction policyid --script-file contracts/perma_lock_ft_contract.plutus > hashes/perma_lock_ft.hash
cardano-cli transaction policyid --script-file contracts/perma_lock_tkn_contract.plutus > hashes/perma_lock_tkn.hash

echo -e "\033[1;33m Perma Lock FT Contract Hash: $(cat hashes/perma_lock_ft.hash) \033[0m"
echo -e "\033[1;33m Perma Lock Tkn Contract Hash: $(cat hashes/perma_lock_tkn.hash) \033[0m"

# end of build
echo -e "\033[1;32m\nBuilding Complete! \033[0m"