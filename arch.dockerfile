# ╔═════════════════════════════════════════════════════╗
# ║                       SETUP                         ║
# ╚═════════════════════════════════════════════════════╝
# GLOBAL
  ARG APP_UID=1000 \
      APP_GID=1000 \
      APP_GO_VERSION=0

# :: FOREIGN IMAGES
  FROM 11notes/util AS util
  FROM 11notes/distroless:talosctl AS distroless-talosctl
  FROM 11notes/distroless:kubectl AS distroless-kubectl
  FROM 11notes/distroless:govc AS distroless-govc
  FROM 11notes/distroless:helm AS distroless-helm
  FROM 11notes/distroless:git AS distroless-git
  FROM 11notes/distroless:curl AS distroless-curl
  FROM 11notes/distroless:hold AS distroless-hold
  FROM 11notes/distroless:jq AS distroless-jq
  FROM 11notes/distroless:yq AS distroless-yq
  FROM 11notes/distroless:kompose AS distroless-kompose
  FROM 11notes/distroless:terraform AS distroless-terraform


# ╔═════════════════════════════════════════════════════╗
# ║                       BUILD                         ║
# ╚═════════════════════════════════════════════════════╝
# :: GOVC
  FROM 11notes/go:${APP_GO_VERSION} AS govc
  ARG APP_GO_VERSION
  COPY --from=distroless-govc / /distroless/
  COPY ./build/go/govc /go/govc
  RUN set -eux; \
    mv /distroless/usr/local/bin/govc /distroless/usr/local/bin/govc.org
  RUN set -ex; \
    cd /go/govc; \
    go mod edit -go=${APP_GO_VERSION}; \
    eleven go build /govc main.go; \
    eleven distroless /govc;


# :: FILE SYSTEM
  FROM alpine AS file-system
  RUN set -eux; \
    mkdir -p /distroless/talosadmin;


# ╔═════════════════════════════════════════════════════╗
# ║                       IMAGE                         ║
# ╚═════════════════════════════════════════════════════╝
  # :: HEADER
  FROM 11notes/alpine:stable

  # :: default arguments
    ARG TARGETPLATFORM \
        TARGETOS \
        TARGETARCH \
        TARGETVARIANT \
        APP_IMAGE \
        APP_NAME \
        APP_VERSION \
        APP_ROOT \
        APP_UID \
        APP_GID \
        APP_NO_CACHE

  # :: default environment
    ENV APP_IMAGE=${APP_IMAGE} \
        APP_NAME=${APP_NAME} \
        APP_VERSION=${APP_VERSION} \
        APP_ROOT=${APP_ROOT} \
        HOME=/talosadmin

  # :: app specific environment
    ENV GOVC_INSECURE="true" \
        GIT_TEMPLATE_DIR=/opt/git/templates \
        GIT_EXEC_PATH=/opt/git \
        TF_PLUGIN_CACHE_DIR="${APP_ROOT}/.terraform.d/init"

  # :: multi-stage
    COPY --from=distroless-talosctl / /
    COPY --from=distroless-kubectl / /
    COPY --from=distroless-helm / /
    COPY --from=distroless-git / /
    COPY --from=distroless-curl / /
    COPY --from=distroless-hold / /
    COPY --from=distroless-jq / /
    COPY --from=distroless-yq / /
    COPY --from=distroless-kompose / /
    COPY --from=distroless-terraform / /
    COPY --from=govc /distroless/ /
    COPY --from=file-system --chown=${APP_UID}:${APP_GID} /distroless/ /
    COPY --chown=${APP_UID}:${APP_GID} ./rootfs/ /

# :: INSTALL
  USER root
  RUN set -eux; \
    apk --update --no-cache add \
      nano \
      coreutils;

# :: EXECUTE
  WORKDIR /talosadmin
  USER ${APP_UID}:${APP_GID}
  ENTRYPOINT ["/usr/local/bin/hold"]