# NEWM Marketplace

The NEWM Marketplace contracts allow the selling of stream tokens for NEWM or USD paid in NEWM. A potential buyer chooses the number of stream tokens they wish to purchase and places their purchase order into the queue. A batcher monitoring the queue automates the purchase order by transaction chaining a buy and refund action. After a few blocks, the buyer will automatically receive their stream tokens inside their wallet.

## Quick Happy Path Setup

This is a quick and dirty setup guide for the happy path. It is not extensive but just serves as a baseline to get things started.

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

Enter the data folder and update the `path_to_socket.sh` file to point at the node socket. The `network.sh` file defaults to preprod.

**mainnet launches require additional reference datum updates and steps**

View the balances with `all_balances.sh`. 

Steps to set up marketplace on preprod:

1. Start by funding the starter-wallet with 10 ADA, collat-wallet with 5 ADA, newm-wallet with 25 ADA, and reference-wallet with 350 ADA
2. Enter the starter-token folder inside scripts, run `mintStarterToken.sh`, and hit enter to mint a starter token.
3. Update `config.json` in the parent folder with starter token information and update the change address as required.
4. Run `complete_build.sh` in the parent folder to compile the contracts with Aiken.
5. Enter the scripts folder and run `00_createScriptReferences.sh`, then wait for the transactions to hit the chain.
6. Enter the reference folder and run `01_createReferenceUTxO.sh`, then wait for the transactions to hit the chain.

Following these steps will properly set up the marketplace contracts. Test by running `02_updateReferenceData.sh` inside the reference folder. The transaction should be able to validate and submit on-chain. 

## NEWM Monster Band Lock Up

Locking a band requires having one of each token prefix from the two policy ids below.

### Official NEWMonster Policy IDs

`e92f13e647afa0691006fb98833b60b61e6eb88d6180e7537bdb94a6`

Required tokens:

- **NEWMonsterDJ**
- **NEWMonsterFlamenco**
- **NEWMonsterHeavyMetal**
- **NEWMonsterHelloWorld**
- **NEWMonsterHipHop**
- **NEWMonsterJazz**
- **NEWMonsterOpera**
- **NEWMonsterPianist**
- **NEWMonsterReggae**
- **NEWMonsterRock**

A total of 10 tokens.

---

`b3e0f7538ba97893b0fea85409cecfbf300d164954da2728406bb571`

Required tokens:

- **NEWMonsterConductor**
- **NEWMonsterCountry**
- **NEWMonsterDisco**
- **NEWMonsterDoubleBass**
- **NEWMonsterDrummer**
- **NEWMonsterKPop**
- **NEWMonsterPercussion**
- **NEWMonsterPunk**
- **NEWMonsterRanchera**
- **NEWMonsterSongwriter**
- **NEWMonsterSwissLandler**

A total of 11 tokens.

A complete band set is 21 tokens from two policy ids.

### Locking The Band

The easiest method is following the happy path in the band_lock_up folder. Before the band is locked, the UTxO is owned by the wallet defined in the band lock datum. First, update the `band-lock-datum.json` file in the scripts/data/band_lock folder. The top field is the payment credential, and the bottom field is the stake credential.

For example, an address in bech32:

`addr_test1qrvnxkaylr4upwxfxctpxpcumj0fl6fdujdc72j8sgpraa9l4gu9er4t0w7udjvt2pqngddn6q4h8h3uv38p8p9cq82qav4lmp`

Has the hex form:

`00d9335ba4f8ebc0b8c9361613071cdc9e9fe92de49b8f2a4782023ef4bfaa385c8eab7bbdc6c98b50413435b3d02b73de3c644e1384b801d4`

Remove the network tag, the first byte, and split into two equal parts of length 56 as shown below.

```json
{
  "constructor": 0,
  "fields": [
    {
      "bytes": "d9335ba4f8ebc0b8c9361613071cdc9e9fe92de49b8f2a4782023ef4"
    },
    {
      "bytes": "bfaa385c8eab7bbdc6c98b50413435b3d02b73de3c644e1384b801d4"
    }
  ]
}
```

Enterprise addresses should leave the bottom field, the stake credential, as an empty string.

Next, enter the band_lock_up folder and create the band lock UTxO with the `01_createBandUTxO.sh` script. This UTxO will only contain ADA. Before the band is locked, the UTxO may be removed with the `02_removeBandUTxO.sh` script if the wallet defined in the datum signs the transaction and receives the entire UTxO back to that address.

The wallet to lock the band should only have Lovelace and the required tokens, as the happy path assumes the simple case. The `03_addToBandUTxO.sh` script will add all tokens to the band lock UTxO. At this point, the band is still removable.

The final step is locking the band by minting the completed asset token and the batcher certificate token. The completed asset token lives with the locked band, but the batcher certificate token does not have destination validation. These two tokens are connected thus the owner of a batcher certificate must find the corresponding completed asset token to burn the tokens together to unlock a specific band. The batcher certificate token may be traded and sold, as the validation logic preserves ownership of the originally locked band.

For the batcher to function properly, a single UTxO containing at least 5 ADA and the batcher certificate token must exist at the batcher address.

## Setting Up Vault UTxOs

A batcher should have at least one vault UTxO. We recommend that the batcher has two vault UTxOs and up to delay_depth+1 vault UTxOs. A batcher with many vaults will reduce the chance of a depth delay cooldown via a profit accumulation transaction. Each vault UTxO will hold a datum with the batcher wallet information. If you follow the batcher setup guide, then the batcher will be just an enterprise address, and the datum in the data/vault folder will have the following form:

A batcher address in bech32:

`addr_test1vqvcpfj8lulfsy22rlxzv2ksykvauahqhztfn5wyzyrlwug3sh9xa`

Has the hex form:

`601980a647ff3e98114a1fcc262ad02599de76e0b89699d1c41107f771`

Remove the first byte, the network tag, and the payment credential reveals itself. Leave the stake credential as a blank string when using an enterprise address.

```json
{
  "constructor": 0,
  "fields": [
    {
      "bytes": "1980a647ff3e98114a1fcc262ad02599de76e0b89699d1c41107f771"
    },
    {
      "bytes": ""
    }
  ]
}
```

It is the same form as the band lock UTxO.

Each vault UTxO requires 10 ADA. The batcher always owns this ADA and can never be removed by anyone else. With at least 20 ADA plus fees for the transaction, run the `01_createVault.sh` script in the vault folder. The script will produce two vault UTxOs for the batcher defined in the datum file. The batcher will automatically find these UTxOs during the sync process.

A batcher holding a batcher certificate with at least one vault UTxO is ready to batch orders for the marketplace.
