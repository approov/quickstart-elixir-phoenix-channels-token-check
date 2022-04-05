ARG ELIXIR_DOCKER_TAG=1.13-slim

FROM elixir:${ELIXIR_DOCKER_TAG}

# Will not prompt for questions
ENV DEBIAN_FRONTEND=noninteractive

ARG OH_MY_ZSH_THEME="amuse"
ARG CONTAINER_USER_NAME="developer"
ARG CONTAINER_UID=1000
ARG CONTAINER_GID=1000

ARG DOCKER_BUILD="/docker-build"
ARG SSL_CA_DIR="/etc/ssl/certs"
ARG DOCKER_BUILD_SCRIPTS_RELEASE="0.0.1.0"

ARG PROXY_CA_NAME="ProxyCA"
ENV PROXY_CA_PEM="${PROXY_CA_NAME}.pem"

ARG ROOT_CA_DIR=/.certificates
ARG ROOT_CA_NAME="Self_Signed_Root_CA"

ENV USER=${CONTAINER_USER_NAME}
ENV HOME=/home/"${CONTAINER_USER_NAME}"
ENV CONTAINER_HOME=/home/"${CONTAINER_USER_NAME}"

ARG DOCKER_PHOENIX_VERSION=1.5.1

ARG NODE_VERSION=10

ENV \
  WORKSPACE_PATH="${CONTAINER_HOME}/workspace" \
  CONTAINER_USER_NAME="${CONTAINER_USER_NAME}" \
  CONTAINER_BIN_PATH="${CONTAINER_HOME}/bin" \
  CONTAINER_UID=${CONTAINER_UID} \
  CONTAINER_GID=${CONTAINER_GID} \
  ROOT_CA_KEY="${ROOT_CA_NAME}.key" \
  ROOT_CA_PEM="${ROOT_CA_NAME}.pem" \
  PROXY_CA_FILENAME="${PROXY_CA_NAME}.crt"

COPY ./.certificates /.certificates

RUN apt update && \
    apt -y upgrade && \

    # Install Required Dependencies
    apt -y install \
        locales \
        tzdata \
        ca-certificates \
        inotify-tools \
        build-essential \
        libnss3-tools \
        lib32stdc++6 \
        zip \
        zsh \
        curl \
        git \
        nano && \

    # Force installation of missing dependencies
    apt -y -f install && \

    mkdir -p "${DOCKER_BUILD}" && \

    curl \
      -fsSl \
      -o archive.tar.gz \
      https://gitlab.com/exadra37-bash/docker/bash-scripts-for-docker-builds/-/archive/"${DOCKER_BUILD_SCRIPTS_RELEASE}"/bash-scripts-for-docker-builds-dev.tar.gz?path=scripts && \
    tar xf archive.tar.gz -C "${DOCKER_BUILD}" --strip 1 && \
    rm -vf archive.tar.gz && \

    "${DOCKER_BUILD}"/scripts/debian/install/inotify-tools.sh && \

    if [ -f "/.certificates/ProxyCA.crt" ]; then \
      "${DOCKER_BUILD}"/scripts/custom-ssl/operating-system/add-custom-authority-certificate.sh \
        "/.certificates/ProxyCA.crt" \
        "/usr/local/share/ca-certificates"; \
    fi && \

    echo "en_GB.UTF-8 UTF-8" > /etc/locale.gen && \
    locale-gen en_GB.UTF-8 && \
    dpkg-reconfigure locales && \

    "${DOCKER_BUILD}"/scripts/utils/debian/add-user-with-bin-folder.sh \
      "${CONTAINER_USER_NAME}" \
      "${CONTAINER_UID}" \
      "/usr/bin/zsh" \
      "${CONTAINER_BIN_PATH}" && \

    "${DOCKER_BUILD}"/scripts/debian/install/oh-my-zsh.sh \
      "${CONTAINER_HOME}" \
      "${OH_MY_ZSH_THEME}" || true && \

    "${DOCKER_BUILD}"/scripts/utils/create-workspace-dir.sh \
      "${WORKSPACE_PATH}" \
      "${CONTAINER_USER_NAME}" && \

    "${DOCKER_BUILD}"/scripts/nodejs/install.sh "${NODE_VERSION}" && \

    # cleaning
    rm -rvf /var/lib/apt/lists/*

USER ${CONTAINER_USER_NAME}

WORKDIR ${CONTAINER_HOME}

ENV ANDROID_HOME="${CONTAINER_HOME}"/.android-home

ENV LANG=en_GB.UTF-8 \
    LANGUAGE=en_GB:en \
    LC_ALL=en_GB.UTF-8

RUN "${DOCKER_BUILD}"/scripts/elixir/phoenix/install-from-git-branch.bash \
      "${DOCKER_PHOENIX_VERSION}"

WORKDIR ${CONTAINER_HOME}/workspace

CMD ["zsh"]
