# Verta — a gaming desktop built on Fedora Atomic (KDE Plasma).
#
# Flavors (VERTA_FLAVOR): verta (AMD / Intel) and verta-nvidia.
# Kernel (KERNEL_FLAVOR): ogc = Universal Blue's gaming kernel (default),
#                         main = Fedora's stock kernel.
#
# Build with scripts/build-image.sh rather than calling podman directly.

ARG BASE_IMAGE=ghcr.io/ublue-os/kinoite-main
ARG FEDORA_VERSION=45
ARG KERNEL_FLAVOR=ogc

# Build scripts and system files live in their own stage so they never end up
# in the final image as-is.
FROM scratch AS ctx
COPY build_files /
COPY system_files /system_files

# Prebuilt kernel + kmods (signed with Universal Blue's key).
FROM ghcr.io/ublue-os/akmods:${KERNEL_FLAVOR}-${FEDORA_VERSION} AS akmods
FROM ghcr.io/ublue-os/akmods-nvidia-open:${KERNEL_FLAVOR}-${FEDORA_VERSION} AS akmods-nvidia

FROM ${BASE_IMAGE}:${FEDORA_VERSION}

ARG FEDORA_VERSION=45
ARG KERNEL_FLAVOR=ogc
ARG VERTA_FLAVOR=verta
ARG VERTA_VERSION=dev
ARG IMAGE_SOURCE=https://github.com/HumandubleOfficial/verta

LABEL org.opencontainers.image.title="Verta" \
      org.opencontainers.image.description="Verta gaming desktop (Fedora Atomic, KDE Plasma)" \
      org.opencontainers.image.version="${VERTA_VERSION}" \
      org.opencontainers.image.source="${IMAGE_SOURCE}"

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=bind,from=akmods,source=/,target=/akmods \
    --mount=type=bind,from=akmods-nvidia,source=/,target=/akmods-nvidia \
    --mount=type=cache,dst=/var/cache \
    --mount=type=tmpfs,dst=/tmp \
    FEDORA_VERSION="${FEDORA_VERSION}" \
    KERNEL_FLAVOR="${KERNEL_FLAVOR}" \
    VERTA_FLAVOR="${VERTA_FLAVOR}" \
    VERTA_VERSION="${VERTA_VERSION}" \
    /ctx/build.sh

RUN bootc container lint
