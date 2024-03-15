# Worst Case Minting

The script will mint $2^{63} - 1$ tokens with the max asset name to the user's wallet. This script is only used to generate a worst case for the contract. Each mint increments the policy script slot value so that each token minted has a unique policy id.