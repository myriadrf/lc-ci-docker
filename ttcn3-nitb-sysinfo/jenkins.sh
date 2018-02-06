#!/bin/sh

# non-jenkins execution: assume local user name
if [ "x$REPO_USER" = "x" ]; then
	REPO_USER=$USER
fi

# non-jenkins execution: put logs in /tmp
if [ "x$WORKSPACE" = "x" ]; then
	WORKSPACE=/tmp
fi

NET_NAME="nitb-sysinfo-tester"

echo Creating network $NET_NAME
docker network create --internal --subnet 172.18.5.0/24 $NET_NAME

# start container with nitb in background
docker volume rm nitb-vol
docker run	--rm \
		--sysctl net.ipv6.conf.all.disable_ipv6=0 \
		--network sigtran --ip 172.18.5.20 \
		-v nitb-vol:/data \
		--name nitb -d \
		$REPO_USER/osmo-nitb-master

# start container with bts in background
docker volume rm bts-vol
docker run	--rm \
		--sysctl net.ipv6.conf.all.disable_ipv6=0 \
		--network sigtran --ip 172.18.5.210 \
		-v bts-vol:/data \
		--name bts -d \
		$REPO_USER/osmo-bts-master


# start docker container with testsuite in foreground
docker volume rm ttcn3-nitb-sysinfo-vol
docker run	--rm \
		--sysctl net.ipv6.conf.all.disable_ipv6=0 \
		--network sigtran --ip 172.18.5.230 \
		-v ttcn3-nitb-sysinfo-vol:/data \
		$REPO_USER/ttcn3-nitb-sysinfo

# stop bts + nitb after test has completed
docker container stop bts
docker container stop nitb

# start some stupid helper container so we can access the volume
docker run	--rm \
		-v ttcn3-nitb-sysinfo-vol:/ttcn3-nitb-sysinfo \
		-v nitb-vol:/nitb \
		-v bts-vol:/bts \
		--name sysinfo-helper -d \
		busybox /bin/sh -c 'sleep 1000 & wait'
rm -rf $WORKSPACE/logs
mkdir -p $WORKSPACE/logs
docker cp sysinfo-helper:/ttcn3-nitb-sysinfo $WORKSPACE/logs
docker cp sysinfo-helper:/nitb $WORKSPACE/logs
docker cp sysinfo-helper:/bts $WORKSPACE/logs
docker container stop -t 0 sysinfo-helper

echo Removing network $NET_NAME
docker network remove $NET_NAME
