# Build provider JAR
FROM node:18-buster-slim AS builder
WORKDIR /app
COPY package.json pnpm-lock.yaml ./
RUN npm install -g pnpm && pnpm install
COPY . .
RUN pnpm run build:jar

# Since quay keycloak is stripped bare of any package manager or curl,
# copy curl from another image
FROM registry.access.redhat.com/ubi9 AS ubi-micro-build
RUN mkdir -p /mnt/rootfs \
 && dnf install \
      --installroot=/mnt/rootfs \
      curl-minimal \
      --releasever=9 \
      --setopt install_weak_deps=false \
      --nodocs -y \
 && dnf --installroot=/mnt/rootfs clean all \
 && rpm --root=/mnt/rootfs -e --nodeps setup

# Final runtime image 
FROM quay.io/keycloak/keycloak:24.0.1 AS final

ENV KC_HEALTH_ENABLED=true
ENV KC_METRICS_ENABLED=true

USER root

# Overlay in curl from our minimal UBI rootfs
COPY --from=ubi-micro-build /mnt/rootfs/ /

# Copy custom provider
COPY --from=builder /app/out/keywind.jar /opt/keycloak/providers/keywind.jar

USER 1000

EXPOSE 8080

ENTRYPOINT ["/opt/keycloak/bin/kc.sh"]
CMD ["start-dev", "--import-realm"]
