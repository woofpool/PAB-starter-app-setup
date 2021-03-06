# Start services

## Prepare configuration data
- create directories for node config
  ```shell
  mkdir $HOME/pab-config
  cd $HOME/pab-config
  mkdir testnet
  ```
- fetch the testnet node config files
  ```shell
  cd testnet
  NODE_BUILD_NUM=$(curl https://hydra.iohk.io/job/Cardano/iohk-nix/cardano-deployment/latest-finished/download/1/index.html | grep -e "build" | sed 's/.*build\/\([0-9]*\)\/download.*/\1/g')
  wget https://hydra.iohk.io/build/${NODE_BUILD_NUM}/download/1/testnet-byron-genesis.json
  wget https://hydra.iohk.io/build/${NODE_BUILD_NUM}/download/1/testnet-topology.json
  wget https://hydra.iohk.io/build/${NODE_BUILD_NUM}/download/1/testnet-shelley-genesis.json
  wget https://hydra.iohk.io/build/${NODE_BUILD_NUM}/download/1/testnet-alonzo-genesis.json
  wget https://hydra.iohk.io/build/${NODE_BUILD_NUM}/download/1/testnet-config.json
  ```
- fetch the PAB config and chainindex config files for `v2021-11-05` tag of `plutus-apps`
  ```shell
  # ensure current working directory is $HOME/pab-config/testnet
  # fetch appropriate config files
  wget https://raw.githubusercontent.com/input-output-hk/plutus-apps/v2021-11-05/plutus-pab/test-node/testnet/chain-index-config.json
  wget https://raw.githubusercontent.com/input-output-hk/plutus-apps/v2021-11-05/plutus-pab/test-node/testnet/pab-config.yml
  ```
## Run Cardano node relay with testnet config
- **In term 1**, run `cardano-node` on port 3003
  ```shell
  cd $HOME/pab-config
  cardano-node -- run \
  --config testnet/testnet-config.json \
  --topology testnet/testnet-topology.json \
  --database-path testnet/db \
  --socket-path testnet/node.sock \
  --port 3003
  ```

- **In another terminal**, ensure the node has fully synced against the testnet (it took ~75 minutes to sync for the author)
  - We can use cardano-cli to check if the node has fully synchronized. 
      ```shell
      cd $HOME/pab-config
      export CARDANO_NODE_SOCKET_PATH=testnet/node.sock
      cardano-cli query tip --testnet-magic 1097911063    
      ```
  - After the sync progress reaches 100%, you can compare the tip info to `cardanoscan` data
    - Visit [cardanoscan website](https://testnet.cardanoscan.io/)
    - Compare the block/slot information with the results of the `cardano-cli query tip` to make sure they agree

## Run the Plutus chain indexer
You can run this while you are still syncing the node against testnet
- **In a new terminal**, run `plutus-chain-index`.
  ```shell
  cd $HOME/pab-config
  plutus-chain-index --config testnet/chain-index-config.json start-index
  # this will store the chain data in /tmp folder based on the `chain-index-config.json`    
  ```
- wait for it to fully sync - query chain-index tip to monitor the progress (it took ~3 hours to sync for the author)
  ```shell
  curl -s http://localhost:9083/tip | jq .
  # compare the tipBlockNo to the cardano node tip block
  
  # you may see the following duplicateBlock errors, but they are harmless
  [chain-index:Error:184] [2021-11-29 17:48:01.10 UTC] {"contents":{"contents":{"contents":{"tipBlockId":"507534faacb02cc212f121065531ac406c64a05a77b1a126b73e0342c4fc429e","tipSlot":{"getSlot":21599},"tipBlockNo":20569,"tag":"Tip"},"tag":"DuplicateBlock"},"tag":"InsertionFailed"},"tag":"Err"}
  ```

## Run the wallet API server
This step starts a wallet API server listening on port 8090. It may not be necessary, but the author made sure the `cardano-node` 
is synced before syncing the wallet
- **In a new terminal**, run `cardano-wallet`
  ```shell
  cd $HOME/pab-config
  cardano-wallet serve \
  --testnet testnet/testnet-byron-genesis.json \
  --node-socket testnet/node.sock
  ```
- ensure fully synced (it only takes a few minutes to sync)
  In the STDOUT logging, look for a message like the following 
  ```log
  [cardano-wallet.pools-engine:Notice:45] [2021-11-15 18:16:56.41 UTC] In sync! 
  ```

## Set up a PAB database and start your application PAB web server
The PAB web server process allows client callers to interact with the application contract schema endpoints
- **In new terminal**, run `pab-game` in command line mode to migrate schema to set up the contract database.
  ```shell
  cd $HOME/pab-config
  pab-game --config testnet/pab-config.yml migrate  
  
  # this will create a file-based, key-value store, `plutus-pab.db` file, in the current directory
  ```
- **In same terminal**, start a PAB webserver up. It may not be necessary, but the author made sure the `cardano-node`
  is synced before syncing the PAB webserver
  ```shell
  pab-game \
  --config testnet/pab-config.yml webserver \
  --passphrase pab123456789
  ```
- Wait for the PAB to start printing messages like below. **Note**: it may seem like it is stuck for 10 minutes or so, before it logs
  the current block/current slot progress.
  ```
  ...
  Current block: 327295. Current slot: 41749136.
  Current block: 327295. Current slot: 41749150.  
  ```
  When the current slot value of the last log line matches the current slot you get when getting the chain tip index,
  then the PAB web server is fully synched.  **Note**: the block value does not seem to align with the testnet blocks.
  ```shell
  curl http://localhost:9083/tip
  ```
- **In a new terminal**, verify contract definitions can be fetched
  ```shell
  curl -H "content-type: application/json" \
    -XGET http://localhost:9080/api/contract/definitions
  ```
  This should show something like:
  ```log
  [{"csrSchemas":[{"argument":{"contents":[["amount",{"tag":"FormSchemaValue"}],["wallet",{"contents":[["getWalletId",{"tag":"FormSchemaString"}]],"tag":"FormSchemaObject"}]],"tag":"FormSchemaObject"},"endpointDescription":{"getEndpointDescription":"Pay to wallet"}}],"csrDefinition":[]}]
  ```
