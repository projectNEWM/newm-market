# NEWM Marketplace



## NEWM Monster Band Lock Up

## Setting Up Vault UTxOs

## Quick Full Happy Path Setup

Following this for setting up your own version of the entire marketplace.

We will need some wallets to run everything.

```bash
./create_wallet.sh wallets/artist-wallet
./create_wallet.sh wallets/batcher-wallet
./create_wallet.sh wallets/buyer1-wallet
./create_wallet.sh wallets/collat-wallet
./create_wallet.sh wallets/reference-wallet
./create_wallet.sh wallets/keeper1-wallet
./create_wallet.sh wallets/keeper2-wallet
./create_wallet.sh wallets/keeper3-wallet
./create_wallet.sh wallets/newm-wallet
./create_wallet.sh wallets/reward-wallet
./create_wallet.sh wallets/starter-wallet
```

Update the path_to_socket.sh file to point at the full node socket. The network.sh is current set to preprod.

Steps to set up:

1. Start by funding the starter-wallet with 10 ADA, collat-wallet with 5 ADA, newm-wallet with 25 ADA, and reference-wallet with 350 ADA
2. Enter the starter-token folder inside of scripts and run mintStarterToken.sh, hit enter to mint
3. Update config.json with starter token information, update the change address as required
4. Run complete_build.sh to compile the contracts
5. Enter the scripts folder and run 00_createScriptReferences.sh, wait for the transactions to hit the chain
6. Enter the reference folder and run 01_createReferenceUTxO.sh, wait for the transactions to hit the chain

View the balances with all_balances.sh. 

Contracts should be set up now. Test by running 02_updateReferenceData.sh inside the reference folder. It should validate and submit. 

Another good test is running the stake validations, 01_registerStake.sh and 02_delegateStake.sh, as they require a valid reference data.
