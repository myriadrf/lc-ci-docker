ARG	REGISTRY
ARG	USER
FROM	$REGISTRY/$USER/debian-bullseye-titan
ARG	OSMO_TTCN3_BRANCH="master"

ADD https://gerrit.osmocom.org/plugins/gitiles/osmo-ttcn3-hacks/+/$OSMO_TTCN3_BRANCH?format=TEXT /tmp/commit
RUN	ttcn3-docker-prepare "$OSMO_TTCN3_BRANCH" hnbgw

VOLUME	/data

COPY	HNBGW_Tests.cfg /data/HNBGW_Tests.cfg

CMD	ttcn3-docker-run hnbgw HNBGW_Tests
