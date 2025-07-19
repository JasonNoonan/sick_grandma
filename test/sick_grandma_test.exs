defmodule SickGrandmaTest do
  use ExUnit.Case
  doctest SickGrandma

  setup do
    # Create a test ETS table
    table = :ets.new(:test_table, [:set, :public, :named_table])
    :ets.insert(table, {"key1", "value1"})
    :ets.insert(table, {"key2", "value2"})

    on_exit(fn ->
      if :ets.info(table) != :undefined do
        :ets.delete(table)
      end
    end)

    {:ok, table: table}
  end

  test "can list ETS tables" do
    {:ok, tables} = SickGrandma.list_tables()
    assert is_list(tables)
    assert length(tables) > 0

    # Check that our test table is in the list
    test_table = Enum.find(tables, fn table -> table.name == :test_table end)
    assert test_table != nil
    assert test_table.size == 2
  end

  test "can dump a specific table", %{table: _table} do
    result = SickGrandma.dump_table(:test_table)
    assert result == :ok
  end

  test "can dump all tables" do
    result = SickGrandma.dump_all_tables()
    assert result == :ok
  end

  test "returns error for non-existent table" do
    result = SickGrandma.dump_table(:non_existent_table)
    assert {:error, _reason} = result
  end

  test "log directory is created" do
    log_dir = SickGrandma.Logger.log_directory_path()

    # Ensure directory exists after a dump
    SickGrandma.dump_all_tables()

    assert File.exists?(log_dir)
    assert File.dir?(log_dir)
  end
end
