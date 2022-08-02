if [ "$ucpi_LOCAL_NODE_TYPE" == "BOOTSTRAP" ]
then
    ./bootstrap_init.sh
else
    ./node_init.sh
fi
