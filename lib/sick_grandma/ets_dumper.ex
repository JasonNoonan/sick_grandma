defmodule SickGrandma.ETSDumper do
  @moduledoc """
  Module responsible for discovering and dumping ETS table data.

  Follows the "let it crash" philosophy - if ETS operations fail,
  the process will crash and be restarted by its supervisor.
  """

  @doc """
  Discovers all ETS tables currently running in the system.

  Returns `{:ok, tables}` where tables is a list of table info maps.
  Will crash if ETS system is unavailable (which indicates a serious system issue).
  """
  def discover_tables do
    tables =
      :ets.all()
      |> Enum.map(&get_table_info/1)
      |> Enum.filter(&(&1 != nil))

    {:ok, tables}
  end

  @doc """
  Dumps data from multiple ETS tables.

  Returns `{:ok, dump_data}` where dump_data contains all table information.
  Will crash if basic operations fail (indicating system issues).
  """
  def dump_tables(tables) when is_list(tables) do
    timestamp = DateTime.utc_now()

    dump_data = %{
      timestamp: timestamp,
      total_tables: length(tables),
      tables: Enum.map(tables, &dump_single_table/1)
    }

    {:ok, dump_data}
  end

  @doc """
  Dumps data from a single ETS table by name or ID.

  Returns `{:ok, table_data}` or `{:error, :table_not_found}`.
  Will crash if ETS system is unavailable.
  """
  def dump_table(table_name_or_id) do
    case get_table_info(table_name_or_id) do
      nil -> {:error, :table_not_found}
      table_info -> {:ok, dump_single_table(table_info)}
    end
  end

  # Private functions

  defp get_table_info(table_id) do
    case :ets.info(table_id) do
      :undefined ->
        nil

      info ->
        %{
          id: safe_value(table_id),
          raw_id: table_id,
          name: Keyword.get(info, :name, table_id),
          type: Keyword.get(info, :type),
          size: Keyword.get(info, :size, 0),
          memory: Keyword.get(info, :memory, 0),
          owner: safe_value(Keyword.get(info, :owner)),
          protection: Keyword.get(info, :protection),
          compressed: Keyword.get(info, :compressed, false)
        }
    end
  end

  defp dump_single_table(table_info) do
    %{raw_id: raw_id} = table_info

    case safe_tab2list(raw_id) do
      {:ok, objects} ->
        Map.put(table_info, :data, objects)

      {:error, reason} ->
        Map.put(table_info, :data, {:error, reason})
    end
  end

  defp safe_tab2list(table_id) do
    case :ets.info(table_id, :protection) do
      :undefined ->
        {:error, :table_deleted}

      :private ->
        {:error, :access_denied}

      _ ->
        {:ok, :ets.tab2list(table_id)}
    end
  end

  defp safe_value(value) when is_pid(value), do: inspect(value)
  defp safe_value(value) when is_reference(value), do: inspect(value)
  defp safe_value(value), do: value
end
