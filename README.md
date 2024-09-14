# NEWM Marketplace

The NEWM Marketplace contracts allow the selling of stream tokens for NEWM or USD paid in NEWM. A potential buyer chooses the number of stream tokens they wish to purchase and places their purchase order into the queue. A batcher monitoring the queue automates the purchase order by transaction chaining a buy and refund action. After a few blocks, the buyer will automatically receive their stream tokens inside their wallet.

## Quick Happy Path Setup

A quick and dirty setup guide for the happy path.

We will need some wallets to run everything. Enter the scripts folder and run the command below.

```bash
mkdir wallets
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

Enter the data folder and update the `path_to_socket.sh` file to point at the node socket. The `network.sh` file is currently set to preprod.

**mainnet launches require additional reference datum updates**

View the balances with `all_balances.sh`. 

Steps to set up:

1. Start by funding the starter-wallet with 10 ADA, collat-wallet with 5 ADA, newm-wallet with 25 ADA, and reference-wallet with 350 ADA
2. Enter the starter-token folder inside of scripts and run `mintStarterToken.sh`, hit enter to mint a starter token.
3. Update `config.json` in the parent folder with starter token information, update the change address as required.
4. Run `complete_build.sh` in the parent folder to compile the contracts with Aiken.
5. Enter the scripts folder and run `00_createScriptReferences.sh`, wait for the transactions to hit the chain.
6. Enter the reference folder and run `01_createReferenceUTxO.sh`, wait for the transactions to hit the chain.

Contracts should be set up now. Test by running `02_updateReferenceData.sh` inside the reference folder. It should validate and submit. 

# Batcher Configuration

This section is dedicated to setting up a batcher as it requires locking up a complete set of band tokens and creating a few vault UTxOs.

## NEWM Monster Band Lock Up

Locking a band requires having 1 of each token prefix from the two policy ids below.

Official NEWMonster Policy IDs

`e92f13e647afa0691006fb98833b60b61e6eb88d6180e7537bdb94a6`

Required Tokens:

- NEWMonsterDJ
- NEWMonsterFlamenco 
- NEWMonsterHeavyMetal
- NEWMonsterHelloWorld
- NEWMonsterHipHop
- NEWMonsterJazz
- NEWMonsterOpera
- NEWMonsterPianist
- NEWMonsterReggae
- NEWMonsterRock

Totalling 10 Tokens

`b3e0f7538ba97893b0fea85409cecfbf300d164954da2728406bb571`

Required Tokens:

- NEWMonsterConductor
- NEWMonsterCountry
- NEWMonsterDisco
- NEWMonsterDoubleBass
- NEWMonsterDrummer
- NEWMonsterKPop
- NEWMonsterPercussion
- NEWMonsterPunk
- NEWMonsterRanchera
- NEWMonsterSongwriter
- NEWMonsterSwissLandler

Totalling 11 Tokens

The easiest method is following the happy path in the band_lock_up folder.

## Setting Up Vault UTxOs
