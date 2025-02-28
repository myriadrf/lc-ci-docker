#!/bin/sh
# Environment variables:
# * KERNEL_TEST: set to 1 to run osmo-ggsn with the kernel module in QEMU
# * KERNEL_BUILD: set to 1 to build the kernel instead of using a pre-built one
# * KERNEL_REMOTE_NAME: git remote name (to add multiple repos in the same local linux clone)
# * KERNEL_URL: git remote url
# * KERNEL_BRANCH: branch to checkout

. ../jenkins-common.sh

KERNEL_TEST="${KERNEL_TEST:-0}"
IMAGE_SUFFIX="${IMAGE_SUFFIX:-master}"
docker_images_require \
	"osmo-ggsn-$IMAGE_SUFFIX" \
	"ttcn3-ggsn-test"

set_clean_up_trap
set -e

mkdir $VOL_BASE_DIR/ggsn-tester
cp GGSN_Tests.cfg $VOL_BASE_DIR/ggsn-tester/
write_mp_osmo_repo "$VOL_BASE_DIR/ggsn-tester/GGSN_Tests.cfg"

mkdir $VOL_BASE_DIR/ggsn

SUBNET=3
network_create $SUBNET

# start container with ggsn in background
GGSN_CMD="osmo-ggsn -c /data/osmo-ggsn.cfg"
GGSN_DOCKER_ARGS=""
if [ "$KERNEL_TEST" = "1" ]; then
	cp osmo-ggsn-kernel-gtp.cfg $VOL_BASE_DIR/ggsn/osmo-ggsn.cfg

	kernel_test_prepare \
		"defconfig" \
		"fragment.config" \
		"initrd-ggsn.sh" \
		"$REPO_USER/osmo-ggsn-$IMAGE_SUFFIX" \
		-v $VOL_BASE_DIR/ggsn:/data

	GGSN_CMD="/kernel-test/run-qemu.sh"
	GGSN_DOCKER_ARGS="
		$(docker_network_params $SUBNET 200)
		$(docker_kvm_param)
		-v "$KERNEL_TEST_DIR:/kernel-test:ro"
		-v "$CACHE_DIR:/cache"
		"
	OSMO_SUT_HOST="172.18.$SUBNET.200"
else
	cp osmo-ggsn.cfg $VOL_BASE_DIR/ggsn/

	GGSN_DOCKER_ARGS="
		$(docker_network_params $SUBNET 201)
		"
	OSMO_SUT_HOST="172.18.$SUBNET.201"
fi
docker run	--rm \
		--cap-add=NET_ADMIN \
		--device /dev/net/tun:/dev/net/tun \
		--sysctl net.ipv6.conf.all.disable_ipv6=0 \
		--ulimit core=-1 \
		-v $VOL_BASE_DIR/ggsn:/data \
		--name ${BUILD_TAG}-ggsn -d \
		$DOCKER_ARGS \
		$GGSN_DOCKER_ARGS \
		$REPO_USER/osmo-ggsn-$IMAGE_SUFFIX \
		/bin/sh -c "$GGSN_CMD >/data/osmo-ggsn.log 2>&1"

kernel_test_wait_for_vm "$VOL_BASE_DIR/ggsn/osmo-ggsn.log"

# start docker container with testsuite in foreground
docker run	--rm \
		--sysctl net.ipv6.conf.all.disable_ipv6=0 \
		$(docker_network_params $SUBNET 202) \
		--ulimit core=-1 \
		-v $VOL_BASE_DIR/ggsn-tester:/data \
		-e "TTCN3_PCAP_PATH=/data" \
		-e "OSMO_SUT_HOST=$OSMO_SUT_HOST" \
		-e "OSMO_SUT_PORT=4260" \
		--name ${BUILD_TAG}-ggsn-test \
		$DOCKER_ARGS \
		$REPO_USER/ttcn3-ggsn-test
