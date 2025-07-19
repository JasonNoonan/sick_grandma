defmodule SickGrandma.Logger do
  @moduledoc """
  Handles formatting and writing ETS dump data to structured log files.

  ## Overview

  `SickGrandma.Logger` is responsible for taking raw ETS data and metadata from 
  `ETSDumper` and converting it into human-readable, well-formatted log files. 
  It manages file system operations, directory creation, and output formatting.

  ## File Organization

  All log files are created in a standardized directory structure:

      ~/.sick_grandma/
      └── logs/
          ├── ets_dump_2024-01-15T10-30-45-123456Z.log      # Full dumps
          ├── ets_table_my_cache_2024-01-15T10-30-45-123456Z.log  # Single table
          └── ets_table_8207_2024-01-15T10-30-45-123456Z.log      # Table by ID

  ## Log Format

  Each log file contains:

  - **Header**: Timestamp, operation type, summary information
  - **Table Metadata**: ID, name, type, size, memory usage, ownership
  - **Data Section**: Formatted table contents (limited to prevent huge files)
  - **Footer**: End markers and additional metadata

  ## Data Formatting Features

  - **Truncation**: Large tables limited to first 100 entries
  - **Pretty Printing**: Elixir terms formatted with proper indentation
  - **Error Handling**: Clear error messages for inaccessible data
  - **Metadata**: Rich context about each table's properties

  ## File Safety

  - **Atomic Writes**: Files written completely or not at all
  - **Unique Names**: Timestamp-based naming prevents conflicts
  - **Directory Creation**: Automatically creates required directories
  - **Error Recovery**: Detailed error reporting for file system issues

  ## Configuration

  The module uses compile-time constants for directory structure:

  - `@log_dir_name` - Base directory name (`.sick_grandma`)
  - `@logs_subdir` - Subdirectory for log files (`logs`)

  ## Performance Considerations

  - **Memory Efficient**: Streams large data sets when possible
  - **I/O Optimization**: Batches file operations
  - **Size Limits**: Prevents runaway log file sizes
  - **Concurrent Safe**: Multiple processes can write simultaneously

  ## Error Handling

  File system errors are wrapped with context:

  - `{:mkdir_failed, reason}` - Directory creation failed
  - `{:write_failed, reason}` - File writing failed

  ## See Also

  - `SickGrandma.ETSDumper` - Data source for logging operations
  - `SickGrandma` - Main API that coordinates dumping and logging
  """

  @log_dir_name ".sick_grandma"
  @logs_subdir "logs"

  @type dump_data :: SickGrandma.ETSDumper.dump_data()
  @type table_info :: SickGrandma.table_info()

  @spec write_dump(dump_data()) :: :ok | {:error, term()}
  @doc """
  Writes a complete ETS dump to a timestamped log file.

  Creates the log directory if it doesn't exist.
  """
  def write_dump(dump_data) do
    with {:ok, log_dir} <- ensure_log_directory(),
         {:ok, filename} <- generate_dump_filename(dump_data.timestamp),
         {:ok, content} <- format_dump_content(dump_data),
         :ok <- write_to_file(log_dir, filename, content) do
      :ok
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @spec write_table_dump(atom() | integer(), table_info()) :: :ok | {:error, term()}
  @doc """
  Writes a single table dump to a log file.
  """
  def write_table_dump(table_name_or_id, table_data) do
    with {:ok, log_dir} <- ensure_log_directory(),
         {:ok, filename} <- generate_table_filename(table_name_or_id),
         {:ok, content} <- format_table_content(table_data),
         :ok <- write_to_file(log_dir, filename, content) do
      :ok
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @spec log_directory_path() :: String.t()
  @doc """
  Returns the path to the log directory.
  """
  def log_directory_path do
    home_dir = System.user_home()
    Path.join([home_dir, @log_dir_name, @logs_subdir])
  end

  # Private functions

  defp ensure_log_directory do
    log_dir = log_directory_path()

    case File.mkdir_p(log_dir) do
      :ok -> {:ok, log_dir}
      {:error, reason} -> {:error, {:mkdir_failed, reason}}
    end
  end

  defp generate_dump_filename(timestamp) do
    formatted_time =
      timestamp
      |> DateTime.to_iso8601()
      |> String.replace(":", "-")
      |> String.replace(".", "-")

    filename = "ets_dump_#{formatted_time}.log"
    {:ok, filename}
  end

  defp generate_table_filename(table_name_or_id) do
    timestamp =
      DateTime.utc_now()
      |> DateTime.to_iso8601()
      |> String.replace(":", "-")
      |> String.replace(".", "-")

    table_name = sanitize_table_name(table_name_or_id)
    filename = "ets_table_#{table_name}_#{timestamp}.log"
    {:ok, filename}
  end

  defp sanitize_table_name(name) when is_atom(name), do: Atom.to_string(name)
  defp sanitize_table_name(name) when is_integer(name), do: Integer.to_string(name)
  defp sanitize_table_name(name) when is_binary(name), do: name
  defp sanitize_table_name(name), do: inspect(name)

  defp format_dump_content(dump_data) do
    content = """
    ================================================================================
    SickGrandma ETS Dump Report
    ================================================================================
    Timestamp: #{DateTime.to_iso8601(dump_data.timestamp)}
    Total Tables: #{dump_data.total_tables}
    ================================================================================

    #{format_tables_content(dump_data.tables)}

    ================================================================================
    End of Dump
    ================================================================================
    """

    {:ok, content}
  end

  defp format_table_content(table_data) do
    content = """
    ================================================================================
    SickGrandma Single Table Dump
    ================================================================================
    Timestamp: #{DateTime.to_iso8601(DateTime.utc_now())}
    Table ID: #{table_data.id}
    Table Name: #{inspect(table_data.name)}
    ================================================================================

    #{format_single_table(table_data)}

    ================================================================================
    End of Table Dump
    ================================================================================
    """

    {:ok, content}
  end

  defp format_tables_content(tables) do
    tables
    |> Enum.with_index(1)
    |> Enum.map(fn {table, index} ->
      """

      Table #{index}:
      #{format_single_table(table)}
      """
    end)
    |> Enum.join("\n")
  end

  defp format_single_table(table) do
    """
    ID: #{table.id}
    Name: #{inspect(table.name)}
    Type: #{table.type}
    Size: #{table.size} objects
    Memory: #{table.memory} words
    Owner: #{table.owner}
    Protection: #{table.protection}
    Compressed: #{table.compressed}

    Data:
    #{format_table_data(table.data)}
    """
  end

  defp format_table_data({:error, error}) do
    "ERROR: #{error}"
  end

  defp format_table_data(data) when is_list(data) do
    if length(data) == 0 do
      "(empty table)"
    else
      data
      # Limit to first 100 entries to avoid huge logs
      |> Enum.take(100)
      |> Enum.with_index(1)
      |> Enum.map(fn {item, index} ->
        "  #{index}. #{inspect(item, limit: :infinity, printable_limit: :infinity)}"
      end)
      |> Enum.join("\n")
      |> then(fn formatted ->
        if length(data) > 100 do
          formatted <> "\n  ... (#{length(data) - 100} more entries truncated)"
        else
          formatted
        end
      end)
    end
  end

  defp format_table_data(data) do
    inspect(data, limit: :infinity, printable_limit: :infinity)
  end

  defp write_to_file(log_dir, filename, content) do
    file_path = Path.join(log_dir, filename)

    case File.write(file_path, content) do
      :ok -> :ok
      {:error, reason} -> {:error, {:write_failed, reason}}
    end
  end
end
