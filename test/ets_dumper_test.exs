defmodule SickGrandma.ETSDumperTest do
  use ExUnit.Case
  alias SickGrandma.ETSDumper

  setup do
    # Create a test ETS table
    table = :ets.new(:dumper_test_table, [:set, :public, :named_table])
    :ets.insert(table, {"test_key", "test_value"})
    :ets.insert(table, {123, %{data: "example"}})

    on_exit(fn ->
      if :ets.info(table) != :undefined do
        :ets.delete(table)
      end
    end)

    {:ok, table: table}
  end

  test "can discover ETS tables" do
    {:ok, tables} = ETSDumper.discover_tables()
    assert is_list(tables)
    assert length(tables) > 0

    # Each table should have the expected structure
    table = List.first(tables)
    assert Map.has_key?(table, :id)
    assert Map.has_key?(table, :name)
    assert Map.has_key?(table, :type)
    assert Map.has_key?(table, :size)
    assert Map.has_key?(table, :memory)
  end

  test "can dump multiple tables", %{table: _table} do
    {:ok, tables} = ETSDumper.discover_tables()
    {:ok, dump_data} = ETSDumper.dump_tables(tables)

    assert Map.has_key?(dump_data, :timestamp)
    assert Map.has_key?(dump_data, :total_tables)
    assert Map.has_key?(dump_data, :tables)
    assert dump_data.total_tables == length(tables)
    assert length(dump_data.tables) == length(tables)
  end

  test "can dump a specific table", %{table: _table} do
    {:ok, table_data} = ETSDumper.dump_table(:dumper_test_table)

    assert Map.has_key?(table_data, :id)
    assert Map.has_key?(table_data, :name)
    assert Map.has_key?(table_data, :data)
    assert table_data.name == :dumper_test_table
    assert table_data.size == 2
    assert is_list(table_data.data)
    assert length(table_data.data) == 2
  end

  test "returns error for non-existent table" do
    result = ETSDumper.dump_table(:non_existent_table)
    assert {:error, {:table_not_found, :non_existent_table}} = result
  end
end
