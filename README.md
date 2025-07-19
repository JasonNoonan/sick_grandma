# SickGrandma

A library for dumping ETS table data to log files. SickGrandma provides functionality to discover all running ETS tables in your application and dump their contents to structured log files.

## Features

- **ETS Table Discovery**: Automatically discovers all running ETS tables in the current application
- **Data Dumping**: Extracts and formats data from ETS tables
- **Automatic Logging**: Writes dump data to log files in `~/.sick_grandma/logs/`
- **Directory Management**: Automatically creates log directories if they don't exist
- **Flexible API**: Dump all tables at once or target specific tables

## Installation

Add `sick_grandma` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:sick_grandma, "~> 0.1.0"}
  ]
end
```

## Usage

### Dump All ETS Tables

```elixir
# Dump all discoverable ETS tables to a timestamped log file
SickGrandma.dump_all_tables()
# => :ok
```

### Dump a Specific Table

```elixir
# Dump a specific table by name
SickGrandma.dump_table(:my_table_name)
# => :ok

# Dump a specific table by ID
SickGrandma.dump_table(8207)
# => :ok
```

### List Available Tables

```elixir
# Get information about all discoverable ETS tables
{:ok, tables} = SickGrandma.list_tables()

# Each table info contains:
# %{
#   id: 8207,
#   name: :my_table,
#   type: :set,
#   size: 42,
#   memory: 1024,
#   owner: #PID<0.123.0>,
#   protection: :public,
#   compressed: false
# }
```

## Log Files

Log files are automatically created in `~/.sick_grandma/logs/` with the following naming conventions:

- **Full dumps**: `ets_dump_2024-01-15T10-30-45-123456Z.log`
- **Single table dumps**: `ets_table_my_table_2024-01-15T10-30-45-123456Z.log`

Each log file contains:
- Timestamp of the dump
- Table metadata (ID, name, type, size, memory usage, etc.)
- Complete table data (limited to first 100 entries per table to prevent huge files)

## Example Log Output

```
================================================================================
SickGrandma ETS Dump Report
================================================================================
Timestamp: 2024-01-15T10:30:45.123456Z
Total Tables: 3
================================================================================

Table 1:
ID: 8207
Name: :my_cache
Type: :set
Size: 5 objects
Memory: 512 words
Owner: #PID<0.123.0>
Protection: :public
Compressed: false

Data:
  1. {"user:123", %{name: "John", email: "john@example.com"}}
  2. {"user:456", %{name: "Jane", email: "jane@example.com"}}
  ...
```

## Error Handling

All functions return either `:ok` on success or `{:error, reason}` on failure:

```elixir
case SickGrandma.dump_all_tables() do
  :ok -> 
    IO.puts("Dump completed successfully")
  {:error, reason} -> 
    IO.puts("Dump failed: #{inspect(reason)}")
end
```

## License

MIT

