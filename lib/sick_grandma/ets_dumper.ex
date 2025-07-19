defmodule SickGrandma.ETSDumper do
  @moduledoc """
  Module responsible for discovering and dumping ETS table data.
  """

  @doc """
  Discovers all ETS tables currently running in the system.

  Returns `{:ok, tables}` where tables is a list of table info maps,
  or `{:error, reason}` on failure.
  """
  def discover_tables do
    try do
      tables =
        :ets.all()
        |> Enum.map(&get_table_info/1)
        |> Enum.filter(&(&1 != nil))

      {:ok, tables}
    rescue
      error -> {:error, {:discovery_failed, error}}
    end
  end

  @doc """
  Dumps data from multiple ETS tables.

  Returns `{:ok, dump_data}` where dump_data contains all table information,
  or `{:error, reason}` on failure.
  """
  def dump_tables(tables) when is_list(tables) do
    try do
      timestamp = DateTime.utc_now()

      dump_data = %{
        timestamp: timestamp,
        total_tables: length(tables),
        tables: Enum.map(tables, &dump_single_table/1)
      }

      {:ok, dump_data}
    rescue
      error -> {:error, {:dump_failed, error}}
    end
  end

  @doc """
  Dumps data from a single ETS table by name or ID.
  """
  def dump_table(table_name_or_id) do
    try do
      case get_table_info(table_name_or_id) do
        nil -> {:error, {:table_not_found, table_name_or_id}}
        table_info -> {:ok, dump_single_table(table_info)}
      end
    rescue
      error -> {:error, {:dump_failed, error}}
    end
  end

  # Private functions

  defp get_table_info(table_id) do
    try do
      info = :ets.info(table_id)

      if info do
        %{
          id: safe_value(table_id),
          name: Keyword.get(info, :name, table_id),
          type: Keyword.get(info, :type),
          size: Keyword.get(info, :size, 0),
          memory: Keyword.get(info, :memory, 0),
          owner: safe_value(Keyword.get(info, :owner)),
          protection: Keyword.get(info, :protection),
          compressed: Keyword.get(info, :compressed, false)
        }
      else
        nil
      end
    rescue
      _ -> nil
    end
  end

  defp dump_single_table(table_info) do
    %{id: table_id} = table_info

    try do
      # Get all objects from the table
      objects = :ets.tab2list(table_id)

      Map.put(table_info, :data, objects)
    rescue
      error ->
        Map.put(table_info, :data, {:error, inspect(error)})
    end
  end

  defp safe_value(value) when is_pid(value), do: inspect(value)
  defp safe_value(value) when is_reference(value), do: inspect(value)
  defp safe_value(value), do: value
end
