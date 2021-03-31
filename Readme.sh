read -r -p "Do you need to install Node.js and Go? If you do enter 'yes': " var
case $var in
yes|'yes')
curl https://deb.nodesource.com/setup_12.x | sudo bash
curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
sudo apt update
sudo apt upgrade -y
sudo apt install nodejs=12.* yarn build-essential jq -y
apt install git -y
sudo rm -rf /usr/local/go
curl https://dl.google.com/go/go1.15.7.linux-amd64.tar.gz | sudo tar -C/usr/local -zxvf -
cat <<'EOF' >>$HOME/.profile
export GOROOT=/usr/local/go
export GOPATH=$HOME/go
export GO111MODULE=on
export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin
EOF
source $HOME/.profile
esac

read -r -p "Do you need to install Agoric SDK? If you do enter 'yes': " var
case $var in
yes|'yes')
git clone https://github.com/Agoric/agoric-sdk -b @agoric/sdk@2.15.1
cd agoric-sdk
yarn install
yarn build
(cd packages/cosmic-swingset && make)
esac

read -r -p "Do you need to configure Agoric SDK? If you do enter 'yes': " var
case $var in
yes|'yes')
curl https://testnet.agoric.net/network-config > chain.json
chainName=`jq -r .chainName < chain.json`
echo $chainName
read -r -p "Please enter name of your Agoric node and hit enter: " nodename
ag-chain-cosmos init --chain-id $chainName $nodename
curl https://testnet.agoric.net/genesis.json > $HOME/.ag-chain-cosmos/config/genesis.json 
ag-chain-cosmos unsafe-reset-all
peers=$(jq '.peers | join(",")' < chain.json)
seeds=$(jq '.seeds | join(",")' < chain.json)
echo $peers
echo $seeds
sed -i.bak 's/^log_level/# log_level/' $HOME/.ag-chain-cosmos/config/config.toml
sed -i.bak -e "s/^seeds *=.*/seeds = $seeds/; s/^persistent_peers *=.*/persistent_peers = $peers/" $HOME/.ag-chain-cosmos/config/config.toml
esac

read -r -p "Do you need to create systemd service and start the node? If you do enter 'yes': " var
case $var in
yes|'yes')
rm /etc/systemd/system/ag-chain-cosmos.service
sudo tee <<EOF >/dev/null /etc/systemd/system/ag-chain-cosmos.service
[Unit]
Description=Agoric Cosmos daemon
After=network-online.target

[Service]
User=$USER
ExecStart=$HOME/go/bin/ag-chain-cosmos start --log_level=warn
Restart=on-failure
RestartSec=3
LimitNOFILE=4096

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable ag-chain-cosmos
sudo systemctl daemon-reload
sudo systemctl start ag-chain-cosmos

sed -i.bak 's/^log_level/# log_level/' $HOME/.ag-cosmos-helper/config/config.toml

esac

read -r -p "Do you want to create key for your node (necessary to start validator)? If you do enter 'yes': " var
case $var in
yes|'yes')
ag-cosmos-helper keys add mykey
read -r -p "Save your mnemonic phrase and address. If you want to be validator then fill the address with tokens. For testnet use faucet in Discord channel. Then press any button." ent
esac

read -r -p "Do you want to initialize validator (the script will wait untill the node is synced)? If you do enter 'yes': " var
case $var in
yes|'yes')

echo "Node syncing"
sed -i.bak 's/^log_level/# log_level/' $HOME/.ag-cosmos-helper/config/config.toml
while sleep 5; do
  sync_info=`ag-cosmos-helper status 2>&1 | jq .SyncInfo`
  echo "$sync_info"
  if test `echo "$sync_info" | jq -r .catching_up` == false; then
    echo "Caught up"
    break
  fi
done

curl https://testnet.agoric.net/network-config > chain.json
chainName=`jq -r .chainName < chain.json`
echo $chainName

valaddr=$(ag-chain-cosmos tendermint show-validator)

if ! [ $nodename ]
then 
read -r -p "Please enter name of your Agoric node and hit enter: " nodename
fi

ag-cosmos-helper tx staking create-validator \
  --amount=50000000uagstake \
  --broadcast-mode=block \
  --pubkey=$valaddr\
  --moniker=$nodename\
  --commission-rate="0.10" \
  --commission-max-rate="0.20" \
  --commission-max-change-rate="0.01" \
  --min-self-delegation="1" \
  --from=Key \
  --chain-id=$chainName \
  --gas=auto \
  --gas-adjustment=1.4

esac








