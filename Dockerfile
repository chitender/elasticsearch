# Stage 1: Download patched JARs from Maven Central
FROM maven:3.9-eclipse-temurin-21-alpine AS downloader

WORKDIR /patches

RUN mvn --batch-mode --no-transfer-progress dependency:copy \
        -Dartifact=io.netty:netty-codec:4.1.135.Final \
        -DoutputDirectory=/patches && \
    mvn --batch-mode --no-transfer-progress dependency:copy \
        -Dartifact=io.netty:netty-codec-http:4.1.135.Final \
        -DoutputDirectory=/patches && \
    mvn --batch-mode --no-transfer-progress dependency:copy \
        -Dartifact=io.netty:netty-handler:4.1.135.Final \
        -DoutputDirectory=/patches && \
    mvn --batch-mode --no-transfer-progress dependency:copy \
        -Dartifact=com.fasterxml.jackson.core:jackson-core:2.15.4 \
        -DoutputDirectory=/patches && \
    mvn --batch-mode --no-transfer-progress dependency:copy \
        -Dartifact=com.nimbusds:nimbus-jose-jwt:9.37.2 \
        -DoutputDirectory=/patches && \
    mvn --batch-mode --no-transfer-progress dependency:copy \
        -Dartifact=net.minidev:json-smart:2.4.9 \
        -DoutputDirectory=/patches && \
    mvn --batch-mode --no-transfer-progress dependency:copy \
        -Dartifact=org.lz4:lz4-java:1.8.1 \
        -DoutputDirectory=/patches && \
    mvn --batch-mode --no-transfer-progress dependency:copy \
        -Dartifact=org.yaml:snakeyaml:2.0 \
        -DoutputDirectory=/patches && \
    mvn --batch-mode --no-transfer-progress dependency:copy \
        -Dartifact=org.bouncycastle:bcprov-jdk18on:1.84 \
        -DoutputDirectory=/patches && \
    mvn --batch-mode --no-transfer-progress dependency:copy \
        -Dartifact=org.bouncycastle:bcpkix-jdk18on:1.84 \
        -DoutputDirectory=/patches && \
    mvn --batch-mode --no-transfer-progress dependency:copy \
        -Dartifact=org.bouncycastle:bcutil-jdk18on:1.84 \
        -DoutputDirectory=/patches

# Stage 2: Official image with vulnerable JARs replaced
FROM docker.elastic.co/elasticsearch/elasticsearch:7.17.28

USER root

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

COPY --from=downloader /patches/*.jar /tmp/patches/

RUN set -eux; \
    find /usr/share/elasticsearch -name "elasticsearch-sql-cli-*.jar" -delete; \
    for new_jar in /tmp/patches/*.jar; do \
        base=$(basename "$new_jar" .jar | sed 's/-[0-9].*//'); \
        found=0; \
        while IFS= read -r old_jar; do \
            echo "Replacing: $old_jar -> $(basename $new_jar)"; \
            dir=$(dirname "$old_jar"); \
            rm -f "$old_jar"; \
            cp "$new_jar" "$dir/"; \
            chmod 644 "$dir/$(basename $new_jar)"; \
            found=1; \
        done < <(find /usr/share/elasticsearch -name "${base}-*.jar" 2>/dev/null); \
        [ "$found" -eq 0 ] && echo "WARNING: no existing JAR matched base=$base"; \
    done; \
    rm -rf /tmp/patches

USER 1000
