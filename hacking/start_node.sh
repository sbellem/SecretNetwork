#!/bin/bash
set +x

docker-compose down
set -e

rm -rf secretd-1
rm -rf secretd-2


mkdir -p secretd-1
mkdir -p secretd-2
mkdir -p genesis

docker-compose up localsecret-1 -d
sleep 5
cp secretd-1/config/genesis.json genesis/genesis.json
docker-compose up localsecret-2
docker-compose up localsecret-2 -d

#waiting to build secretd and start node
progs=$(docker-compose exec localsecret-2 ps -ef)
while [[ "$progs" != *"secretd start --rpc.laddr tcp://0.0.0.0:26657"* ]] 
do 
    progs=$(docker-compose exec localsecret-2 ps -ef)
    ./logs.sh    
    echo "Waiting for secretd build and node start..."
    sleep 5

done

#waiting for blocks to start being produced before turning of localsecret-1
logs=$(docker-compose exec localsecret-2 cat /root/out )
while [[ "$logs" != *"finalizing commit of block"* ]] 
do 
    logs=$(docker-compose exec localsecret-2 cat /root/out )
    ./logs.sh 
    echo "Waiting for blocks to be produced..."
    sleep 5
done

docker-compose stop localsecret-1
./logs.sh
