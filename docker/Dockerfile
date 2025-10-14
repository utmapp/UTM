FROM ghcr.io/cirruslabs/macos-runner:sonoma

SHELL ["/bin/bash", "-lc"]

WORKDIR /workspace

COPY docker-build.sh /usr/local/bin/docker-build.sh
RUN chmod +x /usr/local/bin/docker-build.sh

ENTRYPOINT ["/usr/local/bin/docker-build.sh"]
