defmodule Echo.Repo do

  defp _key(%{uid: uid} = _record) do
    Utils.sha256(uid)
  end

  def insert(record, table) do
    case :ets.insert_new(table, {_key(record), record}) do
      true ->
        {:ok, record}

      false ->

        {:error, :already_exists}
    end
  end

  def insert_or_update(record, table) do
    case :ets.insert(table, {_key(record), record}) do
      true ->
        {:ok, record}

      false ->

        {:error, :insert_or_update_failed}
    end
  end

  def update(record, table) do
    case lookup(record.uid, table) do
      {:error, :record_not_found} ->
        {:error, :record_not_found}

      {:ok, result} ->
        record = Map.merge(result, record)
        :ets.insert(table, {_key(record), record})
        {:ok, record}
    end
  end

  def lookup(uid, table) do
    case :ets.lookup(table, _key(%{uid: uid})) do
      [{_key, record}] ->
        {:ok, record}

      _ ->
        {:error, :record_not_found}
    end
  end

  def all!(table) do
    records = :ets.tab2list(table)
    |> Enum.map(fn {_id, todo} -> todo end)

    records
  end

  def delete(uid, table) do
    :ets.delete(table, _key(%{uid: uid}))
  end

end
