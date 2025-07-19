defmodule SickGrandma do
  @moduledoc """
  SickGrandma is a comprehensive library for dumping ETS table data to structured log files.

  ## Overview

  SickGrandma provides a simple yet powerful API for inspecting and dumping ETS (Erlang Term Storage) 
  table data. Whether you need to debug production issues, analyze data patterns, or create backups 
  of in-memory data, SickGrandma makes it easy to extract and examine ETS table contents.

  ## Key Features

  - **Automatic Discovery**: Finds all accessible ETS tables in your application
  - **Flexible Dumping**: Dump all tables at once or target specific tables
  - **Structured Logging**: Creates organized, timestamped log files
  - **Safe Operations**: Handles table permissions and concurrent access gracefully
  - **Detailed Metadata**: Captures table properties like size, memory usage, and protection level

  ## Quick Start

      # Dump all ETS tables
      SickGrandma.dump_all_tables()

      # Dump a specific table
      SickGrandma.dump_table(:my_table)

      # List available tables
      {:ok, tables} = SickGrandma.list_tables()

  ## Log File Location

  All dumps are saved to `~/.sick_grandma/logs/` with descriptive filenames:
  - Full dumps: `ets_dump_2024-01-15T10-30-45-123456Z.log`
  - Single table: `ets_table_my_table_2024-01-15T10-30-45-123456Z.log`

  ## Error Handling

  All functions follow Elixir conventions, returning `:ok` on success or `{:error, reason}` 
  on failure. The library follows the "let it crash" philosophy for system-level failures 
  while gracefully handling expected errors like missing tables or permission issues.

  ## Architecture

  SickGrandma consists of three main components:
  - `SickGrandma` - Main API module (this module)
  - `SickGrandma.ETSDumper` - Core ETS discovery and data extraction
  - `SickGrandma.Logger` - File writing and formatting operations
  """

  alias SickGrandma.{ETSDumper, Logger}

  @type table_identifier :: atom() | integer()
  @type dump_result :: :ok | {:error, term()}
  @type table_info :: %{
          id: term(),
          raw_id: :ets.tid(),
          name: atom() | :ets.tid(),
          type: :set | :ordered_set | :bag | :duplicate_bag,
          size: non_neg_integer(),
          memory: non_neg_integer(),
          owner: String.t(),
          protection: :public | :protected | :private,
          compressed: boolean()
        }

  @spec dump_all_tables() :: dump_result()
  @doc """
  Dumps all discoverable ETS tables to a timestamped log file.

  This function discovers all ETS tables accessible to the current process, extracts their 
  data and metadata, and writes everything to a comprehensive log file in the 
  `~/.sick_grandma/logs/` directory.

  ## Behavior

  - Discovers all ETS tables using `:ets.all()`
  - Skips tables that are private or have been deleted during the dump process
  - Creates the log directory if it doesn't exist
  - Generates a timestamped filename to avoid conflicts
  - Limits table data to first 100 entries per table to prevent huge files

  ## Return Values

  - `:ok` - Dump completed successfully
  - `{:error, {:mkdir_failed, reason}}` - Could not create log directory
  - `{:error, {:write_failed, reason}}` - Could not write to log file

  ## Examples

      # Basic usage
      iex> SickGrandma.dump_all_tables()
      :ok

      # With error handling
      iex> case SickGrandma.dump_all_tables() do
      ...>   :ok -> 
      ...>     "All tables dumped successfully"
      ...>   {:error, reason} -> 
      ...>     "Dump failed: \#{inspect(reason)}"
      ...> end
      "All tables dumped successfully"

  ## Performance Considerations

  - Large tables (>100 entries) are truncated in the log output
  - Memory usage scales with the number and size of tables
  - File I/O is synchronous and may block for large dumps

  ## See Also

  - `dump_table/1` for dumping specific tables
  - `list_tables/0` for inspecting available tables without dumping
  """
  @doc section: :main_api
  def dump_all_tables do
    with {:ok, tables} <- ETSDumper.discover_tables(),
         {:ok, data} <- ETSDumper.dump_tables(tables),
         :ok <- Logger.write_dump(data) do
      :ok
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @spec dump_table(table_identifier()) :: dump_result()
  @doc """
  Dumps a specific ETS table by name or table ID to a dedicated log file.

  This function targets a single ETS table for dumping, creating a focused log file 
  containing only that table's data and metadata. Useful when you need to examine 
  a specific table without the overhead of dumping all tables.

  ## Parameters

  - `table_name_or_id` - Either an atom table name or integer table ID

  ## Behavior

  - Attempts to locate the specified table
  - Extracts all accessible data and metadata
  - Creates a dedicated log file with table-specific naming
  - Handles permission errors gracefully

  ## Return Values

  - `:ok` - Table dumped successfully
  - `{:error, :table_not_found}` - Specified table doesn't exist or was deleted
  - `{:error, {:mkdir_failed, reason}}` - Could not create log directory
  - `{:error, {:write_failed, reason}}` - Could not write to log file

  ## Examples

      # Dump by table name
      iex> table = :ets.new(:my_cache, [:set, :public, :named_table])
      iex> :ets.insert(table, {"user:123", %{name: "John"}})
      iex> result = SickGrandma.dump_table(:my_cache)
      iex> :ets.delete(table)
      iex> result
      :ok

      # Dump by table ID
      iex> table_id = :ets.new(:temp_table, [:bag, :public])
      iex> SickGrandma.dump_table(table_id)
      :ok
      iex> :ets.delete(table_id)
      true

      # Handle missing table
      iex> SickGrandma.dump_table(:nonexistent_table)
      {:error, :table_not_found}

  ## Table Access

  - Public and protected tables can be fully dumped
  - Private tables will result in access denied errors
  - Tables deleted during the dump process are handled gracefully

  ## See Also

  - `dump_all_tables/0` for dumping all tables at once
  - `list_tables/0` for discovering available table names and IDs
  """
  @doc section: :table_ops
  def dump_table(table_name_or_id) do
    with {:ok, data} <- ETSDumper.dump_table(table_name_or_id),
         :ok <- Logger.write_table_dump(table_name_or_id, data) do
      :ok
    else
      {:error, :table_not_found} -> {:error, :table_not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec list_tables() :: {:ok, [table_info()]}
  @doc """
  Lists all discoverable ETS tables with their metadata.

  This function provides a comprehensive overview of all ETS tables accessible to the 
  current process without actually dumping their data. Useful for exploration, 
  monitoring, and deciding which tables to dump.

  ## Behavior

  - Discovers all ETS tables using `:ets.all()`
  - Extracts metadata for each accessible table
  - Filters out tables that become unavailable during discovery
  - Does not access table data, only metadata

  ## Return Values

  Returns `{:ok, tables}` where `tables` is a list of table information maps.

  Each table map contains:
  - `:id` - Printable table identifier
  - `:raw_id` - Original ETS table reference
  - `:name` - Table name (atom or table ID if unnamed)
  - `:type` - Table type (`:set`, `:ordered_set`, `:bag`, `:duplicate_bag`)
  - `:size` - Number of objects in the table
  - `:memory` - Memory usage in words
  - `:owner` - Process ID of the table owner
  - `:protection` - Access level (`:public`, `:protected`, `:private`)
  - `:compressed` - Whether the table uses compression

  ## Examples

      # Basic usage
      iex> {:ok, tables} = SickGrandma.list_tables()
      iex> is_list(tables)
      true

      # Examine table metadata structure
      iex> {:ok, tables} = SickGrandma.list_tables()
      iex> case tables do
      ...>   [table | _] -> 
      ...>     Map.has_key?(table, :name) and Map.has_key?(table, :size)
      ...>   [] -> 
      ...>     true  # No tables is also valid
      ...> end
      true

  ## Use Cases

  - **Discovery**: Find interesting tables to dump
  - **Monitoring**: Track table sizes and memory usage
  - **Debugging**: Identify table ownership and protection levels
  - **Planning**: Decide which tables need detailed examination

  ## Performance

  This operation is lightweight as it only reads table metadata, not data.
  Performance scales with the number of tables in the system.

  ## Error Handling

  This function follows the "let it crash" philosophy. If the ETS system is 
  unavailable, the process will crash, indicating a serious system issue that 
  should be handled by a supervisor.

  ## See Also

  - `dump_all_tables/0` for dumping all discovered tables
  - `dump_table/1` for dumping a specific table from the list
  """
  @doc section: :utilities
  def list_tables do
    ETSDumper.discover_tables()
  end
end
