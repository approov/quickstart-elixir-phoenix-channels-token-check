defmodule Echo.User do

  require Logger

  @table :users

  def create(%{"username" => username, "password" => password} = _params)
    when is_binary(username)
    and byte_size(username) > 0
    and is_binary(password)
    and byte_size(password) >= 8
  do
    user = %{
      uid: Utils.build_user_uid(username: username),
      username: Utils.sha256(username),
      password_hash: _hash_password(username, password)
    }

    IO.inspect user

    case Echo.Repo.insert(user, @table) do
      {:ok, record} ->
        {:ok, %{uid: record.uid}}

      {:error, :already_exists} ->
        Logger.debug("Cannot create a user that already exists.")
        {:error, :user_already_exists}
    end
  end

  def authenticate(%{"username" => username, "password" => password})
    when is_binary(username)
    and byte_size(username) > 0
    and is_binary(password)
    and byte_size(password) >= 8
  do
    with {:ok, user} <- _verify_password(username, password),
         token <- _encrypted_token(%{uid: user.uid})
    do
      {:ok, %{token: "Bearer #{token}"}}
    else
      _ ->
        {:error, :failed_authentication}
    end
  end

  defp _hash_password(username, password) do
     _build_password(username, password)
     |> Bcrypt.hash_pwd_salt()
  end

  defp _build_password(username, password) do
    "#{username}#{password}#{Utils.secret_key_base()}"
  end

  defp _verify_password(username, password) do
    user_uid = Utils.build_user_uid(username: username)
    password = _build_password(username, password)

    with {:ok, user} <- Echo.Repo.lookup(user_uid, @table),
         true <- Bcrypt.verify_pass(password, user.password_hash)
    do
      {:ok, user}
    else
      {:error, _reason} ->
        Logger.debug("User not found")
        {:error, :user_not_found}

      false ->
        Logger.debug("Failed password verification")
        {:error, :failed_password_verificarion}
    end
  end

  defp _encrypted_token(token) do
    Phoenix.Token.encrypt(Utils.secret_key_base(), Utils.encryption_secret(), token)
  end

  defp _decrypt_token(token) do
    # Valid for 1 day: 86400
    Phoenix.Token.decrypt(Utils.secret_key_base(), Utils.encryption_secret(), token, max_age: 86400)
  end

  def authorize(token: "Bearer " <> token) when is_binary(token) do
    with  {:ok, %{uid: user_uid} = user} <- _decrypt_token(token),
          {:ok, _user} <- Echo.Repo.lookup(user_uid, @table)
      do
        {:ok, user}
      else
        {:error, :record_not_found} ->
          Logger.debug("The decrypted token has a user uid not found in the database: %{token: #{token}}")
          {:error, :failed_authorization}

        {:error, reason} ->
          Logger.debug("Failed to decrypt the token: %{reason: #{reason}, token: #{token}}")
          {:error, :failed_authorization}
    end
  end

  def authorize(token: token) do
    Logger.debug("Token with invalid format: %{token: #{token}}")
    {:error, :failed_authorization}
  end

  def authorize(params: %{"Authorization" => token}), do: authorize(token: token)
  def authorize(params: _params), do: {:error, :missing_authorization_header}

  def can_do_action?(_action, _current_user) do
    # Add your logic here as you see fit.
    true
  end

end
