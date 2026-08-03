FROM ubuntu:22.04

ENV UID="1000" \
    GID="1000"

# The Linux dedicated server distributed through Steam is x86-64 only.
RUN test "$(dpkg --print-architecture)" = "amd64" || \
    (echo "Project Zomboid dedicated server requires an amd64/x86-64 host." >&2 && exit 1)

RUN apt-get update && \
    apt-get install --no-install-recommends -y \
        ca-certificates \
        lib32gcc-s1 \
        curl \
        default-jre \
        util-linux \
    && apt-get clean autoclean \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

RUN useradd --uid 1000 --user-group --create-home --shell /bin/false pzombie && \
    usermod --append --groups users pzombie

EXPOSE 16261/udp
EXPOSE 16262/udp
EXPOSE 27015/tcp

VOLUME ["/data/server-file", "/data/config"]

COPY entry.sh /data/scripts/entry.sh
RUN chmod 0755 /data/scripts/entry.sh

CMD ["/data/scripts/entry.sh"]
