defmodule SickGrandma do
  @moduledoc """
  SickGrandma is a library for dumping ETS table data to log files.

  This library provides functionality to:
  - Discover all running ETS tables in the current application
  - Dump their contents to structured log files
  - Automatically create log directories as needed
  """

  alias SickGrandma.{ETSDumper, Logger}

  @doc """
  Dumps all ETS tables to log files in ~/.sick_grandma/logs/

  Returns `:ok` on success or `{:error, reason}` on failure.

  ## Examples

      iex> case SickGrandma.dump_all_tables() do
      ...>   :ok -> :success
      ...>   {:error, _} -> :error
      ...> end
      :success
  """
  def dump_all_tables do
    with {:ok, tables} <- ETSDumper.discover_tables(),
         {:ok, data} <- ETSDumper.dump_tables(tables),
         :ok <- Logger.write_dump(data) do
      :ok
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Dumps a specific ETS table by name or table ID.

  ## Examples

      iex> table = :ets.new(:test_table, [:set, :public])
      iex> :ets.insert(table, {"key", "value"})
      iex> result = SickGrandma.dump_table(table)
      iex> :ets.delete(table)
      iex> result
      :ok
  """
  def dump_table(table_name_or_id) do
    with {:ok, data} <- ETSDumper.dump_table(table_name_or_id),
         :ok <- Logger.write_table_dump(table_name_or_id, data) do
      :ok
    else
      {:error, :table_not_found} -> {:error, :table_not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Lists all discoverable ETS tables.

  Returns a list of table information maps.
  Will crash if ETS system is unavailable.
  """
  def list_tables do
    ETSDumper.discover_tables()
  end
end
