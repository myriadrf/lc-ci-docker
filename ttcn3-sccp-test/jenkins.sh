#!/bin/sh

. ../jenkins-common.sh
IMAGE_SUFFIX="${IMAGE_SUFFIX:-master}"
# Always require osmo-stp-master since is the only with sccp_demo_user installed
docker_images_require \
	"debian-stretch-build" \
	"osmo-stp-master" \
	"debian-stretch-titan" \
	"ttcn3-sccp-test"

mkdir $VOL_BASE_DIR/sccp-tester
cp SCCP_Tests.cfg $VOL_BASE_DIR/sccp-tester/

mkdir $VOL_BASE_DIR/sccp
cp sccp_demo_user.cfg $VOL_BASE_DIR/sccp/

network_create 172.18.22.0/24

echo Starting container with sccp_demo_user
docker run	--rm \
		--network $NET_NAME --ip 172.18.22.200 \
		-v $VOL_BASE_DIR/sccp:/data \
		--name ${BUILD_TAG}-stp -d \
		$REPO_USER/osmo-stp-master \
		/bin/sh -c "sccp_demo_user -l 172.18.22.200 -r 172.18.22.203 -C /data/sccp_demo_user.cfg >>/data/sccp_demo_user.log 2>&1"


echo Starting container with SCCP testsuite
docker run	--rm \
		--network $NET_NAME --ip 172.18.22.203 \
		-e "TTCN3_PCAP_PATH=/data" \
		-v $VOL_BASE_DIR/sccp-tester:/data \
		--name ${BUILD_TAG}-ttcn3-sccp-test \
		$REPO_USER/ttcn3-sccp-test

docker container kill ${BUILD_TAG}-stp

network_remove
collect_logs