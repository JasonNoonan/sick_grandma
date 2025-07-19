# Getting Started with SickGrandma

SickGrandma is a powerful library for dumping ETS (Erlang Term Storage) table data to structured log files. This guide will help you get up and running quickly.

## Installation

Add `sick_grandma` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:sick_grandma, "~> 0.1.0"}
  ]
end
```

Then run:

```bash
mix deps.get
```

## Basic Usage

### Quick Start

The simplest way to use SickGrandma is to dump all ETS tables at once:

```elixir
# Dump all discoverable ETS tables
SickGrandma.dump_all_tables()
# => :ok
```

This will create a timestamped log file in `~/.sick_grandma/logs/` containing all accessible ETS table data.

### Exploring Available Tables

Before dumping, you might want to see what tables are available:

```elixir
# List all discoverable ETS tables
{:ok, tables} = SickGrandma.list_tables()

# Examine the first table
[first_table | _] = tables
IO.inspect(first_table)
# => %{
#   id: 8207,
#   name: :my_cache,
#   type: :set,
#   size: 42,
#   memory: 1024,
#   owner: "#PID<0.123.0>",
#   protection: :public,
#   compressed: false
# }
```

### Dumping Specific Tables

If you only need data from specific tables:

```elixir
# Dump by table name
SickGrandma.dump_table(:my_cache)
# => :ok

# Dump by table ID
SickGrandma.dump_table(8207)
# => :ok
```

## Understanding Log Files

### File Locations

All log files are created in `~/.sick_grandma/logs/` with descriptive names:

- **Full dumps**: `ets_dump_2024-01-15T10-30-45-123456Z.log`
- **Single table dumps**: `ets_table_my_cache_2024-01-15T10-30-45-123456Z.log`

### Log File Structure

Each log file contains:

1. **Header** - Timestamp and summary information
2. **Table Metadata** - Properties like size, memory usage, protection level
3. **Data Section** - Actual table contents (limited to first 100 entries)
4. **Footer** - End markers

Example log output:

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

SickGrandma uses standard Elixir error handling patterns:

```elixir
case SickGrandma.dump_all_tables() do
  :ok -> 
    IO.puts("Dump completed successfully")
  {:error, {:mkdir_failed, reason}} -> 
    IO.puts("Could not create log directory: #{inspect(reason)}")
  {:error, {:write_failed, reason}} -> 
    IO.puts("Could not write log file: #{inspect(reason)}")
  {:error, reason} -> 
    IO.puts("Dump failed: #{inspect(reason)}")
end
```

Common error scenarios:

- **Directory creation fails** - Usually due to permission issues
- **File writing fails** - Disk space or permission problems
- **Table not found** - Table was deleted between discovery and dumping

## Table Access Permissions

SickGrandma respects ETS table protection levels:

- **Public tables** - Full access to data and metadata
- **Protected tables** - Access depends on process ownership
- **Private tables** - Metadata only, data access denied

When a table can't be accessed, you'll see an error message in the log instead of the data.

## Performance Considerations

- **Large tables** are automatically truncated to the first 100 entries in logs
- **Memory usage** scales with the number and size of tables being dumped
- **File I/O** is synchronous and may block for very large dumps

## Next Steps

- Read the [Advanced Usage Guide](advanced-usage.html) for more sophisticated use cases
- Check out the [API Reference](SickGrandma.html) for complete function documentation
- Explore the source code to understand the internal architecture

## Common Use Cases

### Development and Debugging

```elixir
# Quick debug dump during development
SickGrandma.dump_all_tables()

# Check what's in a specific cache
SickGrandma.dump_table(:user_cache)
```

### Production Monitoring

```elixir
# Scheduled dumps for analysis
Task.start(fn ->
  case SickGrandma.dump_all_tables() do
    :ok -> Logger.info("ETS dump completed")
    {:error, reason} -> Logger.error("ETS dump failed: #{inspect(reason)}")
  end
end)
```

### Testing and Validation

```elixir
# Verify test data setup
{:ok, tables} = SickGrandma.list_tables()
test_tables = Enum.filter(tables, &String.contains?(to_string(&1.name), "test"))
assert length(test_tables) > 0
```