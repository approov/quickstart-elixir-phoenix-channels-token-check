defmodule Utils do

  def build_user_uid(username: username) do
    :crypto.hash(:sha256, "#{username}#{secret_key_base()}") |> Base.encode16
  end

  def sha256(text) do
    :crypto.hash(:sha256, "#{secret_key_base()}#{text}") |> Base.encode16
  end

  def secret_key_base() do
    fetch_from_env!(:echo, EchoWeb.Endpoint, :secret_key_base, 64, :string)
  end

  def encryption_secret() do
    fetch_from_env!(:echo, EchoWeb.Endpoint, :encryption_secret, 64, :string)
  end

  def fetch_from_env!(app, module, key, min_length, :string) do
    case Application.fetch_env!(app, module)[key] do
      value when is_binary(value) and byte_size(value) >= min_length ->
        value

      _ ->
        raise %ArgumentError{message: "Environment key #{key} for #{module} value needs to be a string and to have a minimal length of #{min_length} characters."}
    end
  end

  def load_from_system_env!(var, default_value, min_length, :string) when is_binary(var) do
    case System.get_env(var, default_value) do
      value when is_binary(value) and byte_size(value) >= min_length ->
        value

      _ ->
        raise %ArgumentError{message: "System environment var #{var} value needs to be a string and to have a minimal length of #{min_length} characters."}

    end
  end

  def filter_list_of_tuples(list, key) do
    headers_list = Enum.filter(list, fn({header, _value}) -> header === key end)

    case headers_list do
      [{_header, value} | _ ] = list when length(list) === 1 ->
        value
      _ ->
        nil
    end
  end
end
