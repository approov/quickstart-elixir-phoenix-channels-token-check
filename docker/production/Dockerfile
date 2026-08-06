ARG ELIXIR_DOCKER_TAG=1.18.4-otp-27-slim

FROM approov/quickstart-elixir-phoenix-channels:${ELIXIR_DOCKER_TAG}

ARG GIT_CHECKOUT_TO=main
ARG SERVER_NAME=unprotected-server
ARG GIT_CLONE_URL=https://github.com/approov/quickstart-elixir-phoenix-channels-token-check.git

ENV RELEASE_PATH="${CONTAINER_HOME}"/phoenix_release

RUN set -eu; \
    SERVER_PATH="src/${SERVER_NAME}/echo"; \
    GIT_CLONE_PATH="${CONTAINER_HOME}/repo"; \
    git clone --filter=blob:none "${GIT_CLONE_URL}" "${GIT_CLONE_PATH}"; \
    cd "${GIT_CLONE_PATH}"; \
    git checkout "${GIT_CHECKOUT_TO}"; \
    cd "${SERVER_PATH}"; \
    set -a; \
    . ./.env.example; \
    set +a; \
    export SECRET_KEY_BASE="$(openssl rand -hex 64)"; \
    export ENCRYPTION_SECRET="$(openssl rand -hex 64)"; \
    export PLUG_SESSION_SIGNING_SALT="$(openssl rand -hex 32)"; \
    export LIVE_VIEW_SIGNING_SALT="$(openssl rand -hex 32)"; \
    export LIVE_VIEW_DASHBOARD_USER="$(openssl rand -hex 8)"; \
    export LIVE_VIEW_DASHBOARD_PASSWORD="$(openssl rand -hex 12)"; \
    mix deps.get --only prod; \
    mix compile; \
    mix release --path "${RELEASE_PATH}"; \
    rm -rf "${GIT_CLONE_PATH}"

WORKDIR "${RELEASE_PATH}"

CMD ["bin/echo", "start"]
