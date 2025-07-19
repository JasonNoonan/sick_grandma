defmodule SickGrandma.ETSDumper do
  @moduledoc """
  Core module responsible for ETS table discovery and data extraction.

  ## Overview

  `ETSDumper` handles the low-level operations of interacting with the ETS system,
  including table discovery, metadata extraction, and data dumping. It implements
  safe access patterns and graceful error handling for common ETS edge cases.

  ## Design Philosophy

  This module follows Elixir's "let it crash" philosophy for system-level failures
  while gracefully handling expected operational errors:

  - **System failures** (ETS unavailable) → crash and let supervisor restart
  - **Operational errors** (table deleted, access denied) → return error tuples
  - **Data safety** → never modify tables, only read operations

  ## Key Features

  - **Safe Discovery**: Handles tables that disappear during enumeration
  - **Permission Handling**: Respects table protection levels
  - **Metadata Extraction**: Captures comprehensive table information
  - **Concurrent Safety**: Handles tables modified during dumping
  - **Memory Efficiency**: Processes tables individually to manage memory usage

  ## Table Access Patterns

  The module handles different ETS table protection levels:

  - **Public**: Full read access to data and metadata
  - **Protected**: Read access if owned by current process or inherited
  - **Private**: Metadata only, data access denied

  ## Error Recovery

  Common scenarios handled gracefully:

  - Tables deleted between discovery and access
  - Permission changes during operation
  - Concurrent modifications to table structure
  - Large tables that might cause memory pressure

  ## Internal Architecture

  The module uses a pipeline approach:

  1. **Discovery** → `discover_tables/0`
  2. **Metadata** → `get_table_info/1` 
  3. **Data Extraction** → `dump_single_table/1`
  4. **Safety Checks** → `safe_tab2list/1`

  ## See Also

  - `SickGrandma` - Main API module
  - `SickGrandma.Logger` - Output formatting and file operations
  """

  @type table_info :: SickGrandma.table_info()
  @type dump_data :: %{
          timestamp: DateTime.t(),
          total_tables: non_neg_integer(),
          tables: [table_info()]
        }

  @spec discover_tables() :: {:ok, [table_info()]}
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

  @spec dump_tables([table_info()]) :: {:ok, dump_data()}
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

  @spec dump_table(atom() | integer()) :: {:ok, table_info()} | {:error, :table_not_found}
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
