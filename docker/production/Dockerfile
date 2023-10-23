FROM approov/quickstart-elixir-phoenix

ARG GIT_CHECKOUT_TO=main
ARG SERVER_NAME=unprotected-server
ARG GIT_CLONE_URL=https://github.com/approov/quickstart-elixir-phoenix-channels-token-check.git

ENV RELEASE_PATH="${CONTAINER_HOME}"/phoenix_release

RUN \
  SERVER_PATH=src/"${SERVER_NAME}"/echo && \
  GIT_CLONE_PATH="${CONTAINER_HOME}"/repo && \
  git clone "${GIT_CLONE_URL}" "${GIT_CLONE_PATH}" && \
  cd "${GIT_CLONE_PATH}" && \
  git checkout "${GIT_CHECKOUT_TO}" && \
  ls -al && \
  cd "${SERVER_PATH}" && \
  ls -al && \

  # The real values must be provided when starting the release
  # Needed to allow to load from env the variables that raise when missing in releases.exs
  cat .env.example && \
  export $(grep -v '^#' .env.example | xargs -0) && \

  # Just in case the devops doesn't provide new values for the secrets, we will populate thme with random values
  export SECRET_KEY_BASE=$(strings /dev/urandom | grep -o '[[:alpha:]]' | head -n 64 | tr -d '\n'; echo) && \
  export ENCRYPTION_SECRET=$(strings /dev/urandom | grep -o '[[:alpha:]]' | head -n 64 | tr -d '\n'; echo) && \
  export PLUG_SESSION_SIGNING_SALT=$(strings /dev/urandom | grep -o '[[:alpha:]]' | head -n 64 | tr -d '\n'; echo) && \
  export LIVE_VIEW_SIGNING_SALT=$(strings /dev/urandom | grep -o '[[:alpha:]]' | head -n 64 | tr -d '\n'; echo) && \
  export LIVE_VIEW_DASHBOARD_USER=$(strings /dev/urandom | grep -o '[[:alpha:]]' | head -n 8 | tr -d '\n'; echo) && \
  export LIVE_VIEW_DASHBOARD_PASSWORD=$(strings /dev/urandom | grep -o '[[:alpha:]]' | head -n 12 | tr -d '\n'; echo) && \
  env && \

  mix deps.get --only prod && \
  mix compile && \
  MIX_ENV=prod mix release --path "${RELEASE_PATH}" && \

  cd "${RELEASE_PATH}" && \

  rm -rf "${GIT_CLONE_PATH}"

WORKDIR "${RELEASE_PATH}"

RUN ls -al

CMD ["bin/echo", "start"]
