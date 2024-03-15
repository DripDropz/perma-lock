# Happy Path Scripts

Scripts are supposed to be ran in sequential order. Creating scripts references is always first as every other script requires these reference UTxOs to work properly. The first and second scripts depend on using the `lock_ft` or `lock_nft`.