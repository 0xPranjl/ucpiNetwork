#!/bin/bash
# Chainofucpis.org - Public Release.
# Set "mainnet" or "testnet"

NETWORK="mainnet";

command_exists () {
        type "$1" &> /dev/null;
}

install_jq () {
        if command_exists apt-get; then
                apt-get -y update
                apt -y -q install jq
        fi

        if ! command_exists jq; then
                echo "jq: command not found"
                exit 1;
        fi
}

install_ucpid () {
        if command_exists wget; then
                wget "$GOLEVELDB_LINK"
  	        sudo apt install -y ./ucpinetwork_"$LATEST_VERSION"_"$NETWORK"_goleveldb_amd64.deb    
        fi

        if ! command_exists ucpid; then
                echo "ucpid: command not found"
                exit 1;
        fi
}

install_sgx () {

	wget "https://raw.githubusercontent.com/ucpiFoundation/docs/main/docs/node-guides/sgx"
	sudo bash sgx
}

check_release () {

        LATEST_VERSION=$(curl -sL https://api.github.com/repos/ucpilabs/ucpinetwork/releases/latest | jq -r ".tag_name" | sed 's/v//');
        GOLEVELDB_LINK=`curl -sL https://api.github.com/repos/ucpilabs/ucpinetwork/releases/latest | jq -r ".assets[].browser_download_url" | grep "$NETWORK"_goleveldb_amd64.deb`;
        ROCKSDB_LINK=`curl -sL https://api.github.com/repos/ucpilabs/ucpinetwork/releases/latest | jq -r ".assets[].browser_download_url" | grep "$NETWORK"_rocksdb_amd64.deb`;

}

read_installation_method () {
	echo "--------------------------------------------------------------------------------------------";
	echo "This installation file is built for any version of ucpid.";
	echo "Note: Currently does not support SGX check then install, therefor will just install SGX again.";
	echo "";
	echo "This will automatically install a fresh ucpid or update an old ucpid to either rocksdb or golevel";
	echo "depending on current running configuration.";
	echo "";
	echo "<3 from Chainofucpis.org";
	echo "--------------------------------------------------------------------------------------------";
	echo "";
	read -p "Install ucpid [Y/N]? " choice
	case "$choice" in
		y|Y )
			INSTALL="true";
		;;

		n|N )
			exit 0;
		;;

		* )
			echo "Please, enter Y or N to cancel";
		;;
	esac
}

if ! command_exists jq ; then
        install_jq;
fi

check_release;
read_installation_method;
install_sgx;

if ! command_exists ucpid ; then
        install_ucpid;
fi


if [ $(ucpid version) = "$LATEST_VERSION" ]; then 
  echo 'Current Version '$LATEST_VERSION' - Updating not needed! Happy Nodeling - Chainofucpis.org'
else
 if [ $(awk -F \" '/^db_backend =/{print $2}' ~/.ucpid/config/config.toml) = 'goleveldb' ]; then
	echo "This is a golevelDB install"
  	sudo systemctl stop ucpi-node
  	wget "$GOLEVELDB_LINK"
  	sudo apt install -y ./ucpinetwork_"$LATEST_VERSION"_"$NETWORK"_goleveldb_amd64.deb

 else

  	echo "This is a Rocksdb install"
  	sudo systemctl stop ucpi-node
  	wget "$ROCKSDB_LINK"
  	sudo apt install -y ./ucpinetwork_"$LATEST_VERSION"_"$NETWORK"_rocksdb_amd64.deb
 fi


# .Restart the node & modify the service

perl -i -pe 's{^(ExecStart=).*}{ExecStart=\/usr\/local\/bin\/ucpid start}' /etc/systemd/system/ucpi-node.service

systemctl daemon-reload

sudo systemctl start ucpi-node

fi
