#!/bin/bash

# 1 = username
# 2 = moniker
# 3 = chainid
# 4 = persistent peers
# 5 = rpc url (to get genesis file from)
# 6 = registration service (our custom registration helper)
# 7 = docker compose file location

export DEBIAN_FRONTEND=noninteractive

sudo /bin/date +%H:%M:%S > /home/"$1"/install.progress.txt

echo "Creating tmp folder for aesm" >> /home/"$1"/install.progress.txt

# Aesm service relies on this folder and having write permissions
# shellcheck disable=SC2174
mkdir -p -m 777 /tmp/aesmd
chmod -R -f 777 /tmp/aesmd || sudo chmod -R -f 777 /tmp/aesmd || true

echo "Installing docker" >> /home/"$1"/install.progress.txt

sudo apt update
sudo apt install apt-transport-https ca-certificates curl software-properties-common -y
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -

sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu bionic stable"
sudo apt update
sudo apt install docker-ce -y

echo "Adding user $1 to docker group" >> /home/"$1"/install.progress.txt
sudo service docker start
sudo systemctl enable docker
sudo groupadd docker
sudo usermod -aG docker "$1"

echo "Installing docker-compose" >> /home/"$1"/install.progress.txt
# systemctl status docker
sudo curl -L https://github.com/docker/compose/releases/download/1.26.0/docker-compose-"$(uname -s)"-"$(uname -m)" -o /usr/local/bin/docker-compose

sudo chmod +x /usr/local/bin/docker-compose

echo "Creating ucpi node runner" >> /home/"$1"/install.progress.txt

mkdir -p /usr/local/bin/ucpi-node

echo "Copying docker compose file from $7" >> /home/"$1"/install.progress.txt
sudo curl -L "$7" -o /usr/local/bin/ucpi-node/docker-compose.yaml

mainnetstr="mainnet"
if test "${6#*$mainnetstr}" != "$6"
then
  echo "Running with mainnet config" >> /home/"$1"/install.progress.txt
else
  # leaving this here as a placeholder for future versions where we might have to change stuff for testnet vs. mainnet
  echo "Running with testnet config" >> /home/"$1"/install.progress.txt
fi


# replace the tmp paths with home directory ones
sudo sed -i 's/\/tmp\/.ucpid:/\/home\/'$1'\/.ucpid:/g' /usr/local/bin/ucpi-node/docker-compose.yaml
sudo sed -i 's/\/tmp\/.ucpicli:/\/home\/'$1'\/.ucpicli:/g' /usr/local/bin/ucpi-node/docker-compose.yaml
sudo sed -i 's/\/tmp\/.sgx_ucpis:/\/home\/'$1'\/.sgx_ucpis:/g' /usr/local/bin/ucpi-node/docker-compose.yaml

# Open RPC port to the public
perl -i -pe 's/laddr = .+?26657"/laddr = "tcp:\/\/0.0.0.0:26657"/' ~/.ucpid/config/config.toml

# Open P2P port to the outside
perl -i -pe 's/laddr = .+?26656"/laddr = "tcp:\/\/0.0.0.0:26656"/' ~/.ucpid/config/config.toml

echo "Setting ucpi Node environment variables and aliases" >> /home/"$1"/install.progress.txt

export CHAINID=$2
export MONIKER=$3
export PERSISTENT_PEERS=$4
export RPC_URL=$5
export REGISTRATION_SERVICE=$6

# set Aliases and environment variables
{
  echo 'alias ucpicli="docker exec -it ucpi-node_node_1 ucpicli"'
  echo 'alias ucpid="docker exec -it ucpi-node_node_1 ucpid"'
  echo 'alias show-node-id="docker exec -it ucpi-node_node_1 ucpid tendermint show-node-id"'
  echo 'alias show-validator="docker exec -it ucpi-node_node_1 ucpid tendermint show-validator"'
  echo 'alias stop-ucpi-node="docker-compose -f /usr/local/bin/ucpi-node/docker-compose.yaml down"'
  echo 'alias start-ucpi-node="docker-compose -f /usr/local/bin/ucpi-node/docker-compose.yaml up -d"'
  echo "export CHAINID=$2"
  echo "export MONIKER=$3"
  echo "export PERSISTENT_PEERS=$4"
  echo "export RPC_URL=$5"
  echo "export REGISTRATION_SERVICE=$6"
} >> /home/"$1"/.bashrc

# Log these for debugging purposes
{
  echo "CHAINID=$2"
  echo "MONIKER=$3"
  echo "PRSISTENT_PEERS=$4"
  echo "RPC_URL=$5"
  echo "REGISTRATION_SERVICE=$6"
} >> /home/"$1"/install.progress.txt

################################################################
# Configure to auto start at boot					    #
################################################################
file=/etc/init.d/ucpi-node
if [ ! -e "$file" ]
then
  {
    echo '#!/bin/sh'
    printf '\n'
    # shellcheck disable=SC2016
    printf '### BEGIN INIT INFO
# Provides:       ucpi-node
# Required-Start:    $all
# Required-Stop:     $local_fs $network $syslog $named $docker
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: starts ucpi node
# Description:       starts ucpi node running in docker
### END INIT INFO\n\n'
    printf 'mkdir -p -m 777 /tmp/aesmd\n'
    printf 'chmod -R -f 777 /tmp/aesmd || sudo chmod -R -f 777 /tmp/aesmd || true\n'
    printf '\n'
    echo "export CHAINID=$2"
    echo "export MONIKER=$3"
    echo "export PRSISTENT_PEERS=$4"
    echo "export RPC_URL=$5"
    echo "export REGISTRATION_SERVICE=$6"
    printf 'docker-compose -f /usr/local/bin/ucpi-node/docker-compose.yaml up -d\n'
  } | sudo tee /etc/init.d/ucpi-node

	sudo chmod +x /etc/init.d/ucpi-node
	sudo update-rc.d ucpi-node defaults
fi

docker-compose -f /usr/local/bin/ucpi-node/docker-compose.yaml up -d

ucpicli completion > /root/ucpicli_completion
ucpid completion > /root/ucpid_completion

docker cp ucpi-node_node_1:/root/ucpicli_completion /home/"$1"/ucpicli_completion
docker cp ucpi-node_node_1:/root/ucpid_completion /home/"$1"/ucpid_completion

echo 'source /home/'$1'/ucpid_completion' >> /home/"$1"/.bashrc
echo 'source /home/'$1'/ucpicli_completion' >> /home/"$1"/.bashrc

echo "ucpi Node has been setup successfully and is running..." >> /home/"$1"/install.progress.txt
