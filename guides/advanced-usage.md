# Advanced Usage Guide

This guide covers advanced patterns and use cases for SickGrandma, including integration strategies, performance optimization, and production deployment considerations.

## Integration Patterns

### Scheduled Monitoring

Set up periodic ETS dumps for production monitoring:

```elixir
defmodule MyApp.ETSMonitor do
  use GenServer
  require Logger

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    interval = Keyword.get(opts, :interval, :timer.hours(1))
    schedule_dump(interval)
    {:ok, %{interval: interval}}
  end

  def handle_info(:dump_ets, state) do
    case SickGrandma.dump_all_tables() do
      :ok -> 
        Logger.info("Scheduled ETS dump completed successfully")
      {:error, reason} -> 
        Logger.error("Scheduled ETS dump failed: #{inspect(reason)}")
    end
    
    schedule_dump(state.interval)
    {:noreply, state}
  end

  defp schedule_dump(interval) do
    Process.send_after(self(), :dump_ets, interval)
  end
end
```

### Conditional Dumping

Dump tables only when certain conditions are met:

```elixir
defmodule MyApp.ConditionalDumper do
  def dump_if_large_tables(size_threshold \\ 1000) do
    with {:ok, tables} <- SickGrandma.list_tables() do
      large_tables = Enum.filter(tables, &(&1.size > size_threshold))
      
      if length(large_tables) > 0 do
        Logger.info("Found #{length(large_tables)} large tables, dumping...")
        SickGrandma.dump_all_tables()
      else
        Logger.info("No large tables found, skipping dump")
        :ok
      end
    end
  end

  def dump_memory_intensive_tables(memory_threshold \\ 10_000) do
    with {:ok, tables} <- SickGrandma.list_tables() do
      memory_intensive = Enum.filter(tables, &(&1.memory > memory_threshold))
      
      Enum.each(memory_intensive, fn table ->
        Logger.info("Dumping memory-intensive table: #{inspect(table.name)}")
        SickGrandma.dump_table(table.name)
      end)
    end
  end
end
```

### Custom Log Processing

Process log files after creation for additional analysis:

```elixir
defmodule MyApp.LogProcessor do
  def process_latest_dump do
    log_dir = SickGrandma.Logger.log_directory_path()
    
    case find_latest_dump_file(log_dir) do
      {:ok, file_path} -> analyze_dump_file(file_path)
      {:error, :no_files} -> {:error, :no_dump_files_found}
    end
  end

  defp find_latest_dump_file(log_dir) do
    case File.ls(log_dir) do
      {:ok, files} ->
        dump_files = 
          files
          |> Enum.filter(&String.starts_with?(&1, "ets_dump_"))
          |> Enum.sort(:desc)
        
        case dump_files do
          [latest | _] -> {:ok, Path.join(log_dir, latest)}
          [] -> {:error, :no_files}
        end
      
      {:error, _} -> {:error, :no_files}
    end
  end

  defp analyze_dump_file(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        # Extract metrics from log content
        table_count = count_tables(content)
        total_memory = calculate_total_memory(content)
        
        Logger.info("Dump analysis: #{table_count} tables, #{total_memory} words total memory")
        {:ok, %{tables: table_count, memory: total_memory}}
      
      {:error, reason} -> {:error, reason}
    end
  end

  defp count_tables(content) do
    content
    |> String.split("\n")
    |> Enum.count(&String.starts_with?(&1, "Table "))
  end

  defp calculate_total_memory(content) do
    ~r/Memory: (\d+) words/
    |> Regex.scan(content, capture: :all_but_first)
    |> Enum.map(fn [memory_str] -> String.to_integer(memory_str) end)
    |> Enum.sum()
  end
end
```

## Performance Optimization

### Selective Table Dumping

For applications with many ETS tables, consider selective dumping strategies:

```elixir
defmodule MyApp.SelectiveDumper do
  @important_tables [:user_cache, :session_store, :rate_limiter]
  @table_patterns [~r/cache$/, ~r/^temp_/]

  def dump_important_tables do
    with {:ok, tables} <- SickGrandma.list_tables() do
      important_tables = filter_important_tables(tables)
      
      Enum.each(important_tables, fn table ->
        case SickGrandma.dump_table(table.name) do
          :ok -> Logger.debug("Dumped important table: #{inspect(table.name)}")
          {:error, reason} -> Logger.warn("Failed to dump #{inspect(table.name)}: #{inspect(reason)}")
        end
      end)
    end
  end

  defp filter_important_tables(tables) do
    Enum.filter(tables, fn table ->
      table.name in @important_tables or matches_pattern?(table.name)
    end)
  end

  defp matches_pattern?(table_name) do
    table_str = to_string(table_name)
    Enum.any?(@table_patterns, &Regex.match?(&1, table_str))
  end
end
```

### Async Dumping

For non-blocking dumps in production:

```elixir
defmodule MyApp.AsyncDumper do
  def dump_async(callback \\ nil) do
    Task.start(fn ->
      result = SickGrandma.dump_all_tables()
      
      if callback do
        callback.(result)
      end
      
      case result do
        :ok -> Logger.info("Async ETS dump completed")
        {:error, reason} -> Logger.error("Async ETS dump failed: #{inspect(reason)}")
      end
    end)
  end

  def dump_with_timeout(timeout \\ 30_000) do
    task = Task.async(fn -> SickGrandma.dump_all_tables() end)
    
    case Task.yield(task, timeout) || Task.shutdown(task) do
      {:ok, result} -> result
      nil -> {:error, :timeout}
    end
  end
end
```

## Production Considerations

### Error Recovery and Resilience

```elixir
defmodule MyApp.ResilientDumper do
  @max_retries 3
  @retry_delay 5_000

  def dump_with_retry(retries \\ @max_retries) do
    case SickGrandma.dump_all_tables() do
      :ok -> :ok
      {:error, reason} when retries > 0 ->
        Logger.warn("Dump failed (#{@max_retries - retries + 1}/#{@max_retries}): #{inspect(reason)}")
        Process.sleep(@retry_delay)
        dump_with_retry(retries - 1)
      {:error, reason} ->
        Logger.error("Dump failed after #{@max_retries} retries: #{inspect(reason)}")
        {:error, {:max_retries_exceeded, reason}}
    end
  end

  def dump_with_circuit_breaker do
    case :fuse.ask(:ets_dumper, :sync) do
      :ok ->
        case SickGrandma.dump_all_tables() do
          :ok -> 
            :fuse.reset(:ets_dumper)
            :ok
          {:error, reason} -> 
            :fuse.melt(:ets_dumper)
            {:error, reason}
        end
      :blown ->
        {:error, :circuit_breaker_open}
    end
  end
end
```

### Log Rotation and Cleanup

```elixir
defmodule MyApp.LogManager do
  @max_log_files 50
  @max_log_age_days 30

  def cleanup_old_logs do
    log_dir = SickGrandma.Logger.log_directory_path()
    
    with {:ok, files} <- File.ls(log_dir) do
      log_files = 
        files
        |> Enum.filter(&String.starts_with?(&1, "ets_"))
        |> Enum.map(&{&1, file_age_days(Path.join(log_dir, &1))})
        |> Enum.sort_by(fn {_, age} -> age end, :desc)

      # Remove files older than max age
      old_files = Enum.filter(log_files, fn {_, age} -> age > @max_log_age_days end)
      Enum.each(old_files, fn {file, _} -> 
        File.rm(Path.join(log_dir, file))
        Logger.info("Removed old log file: #{file}")
      end)

      # Remove excess files beyond max count
      remaining_files = log_files -- old_files
      if length(remaining_files) > @max_log_files do
        excess_files = Enum.drop(remaining_files, @max_log_files)
        Enum.each(excess_files, fn {file, _} ->
          File.rm(Path.join(log_dir, file))
          Logger.info("Removed excess log file: #{file}")
        end)
      end
    end
  end

  defp file_age_days(file_path) do
    case File.stat(file_path) do
      {:ok, %{mtime: mtime}} ->
        now = :calendar.universal_time()
        diff_seconds = :calendar.datetime_to_gregorian_seconds(now) - 
                      :calendar.datetime_to_gregorian_seconds(mtime)
        div(diff_seconds, 86400)  # Convert to days
      {:error, _} -> 0
    end
  end
end
```

### Health Checks and Monitoring

```elixir
defmodule MyApp.ETSHealthCheck do
  def health_check do
    checks = [
      check_log_directory(),
      check_table_access(),
      check_recent_dumps()
    ]

    case Enum.find(checks, &match?({:error, _}, &1)) do
      nil -> {:ok, :healthy}
      error -> error
    end
  end

  defp check_log_directory do
    log_dir = SickGrandma.Logger.log_directory_path()
    
    case File.mkdir_p(log_dir) do
      :ok -> {:ok, :log_directory_accessible}
      {:error, reason} -> {:error, {:log_directory_inaccessible, reason}}
    end
  end

  defp check_table_access do
    case SickGrandma.list_tables() do
      {:ok, tables} when length(tables) > 0 -> {:ok, :tables_accessible}
      {:ok, []} -> {:warning, :no_tables_found}
      {:error, reason} -> {:error, {:table_access_failed, reason}}
    end
  end

  defp check_recent_dumps do
    log_dir = SickGrandma.Logger.log_directory_path()
    
    case File.ls(log_dir) do
      {:ok, files} ->
        recent_dumps = 
          files
          |> Enum.filter(&String.starts_with?(&1, "ets_dump_"))
          |> Enum.filter(&file_is_recent?/1)
        
        if length(recent_dumps) > 0 do
          {:ok, :recent_dumps_found}
        else
          {:warning, :no_recent_dumps}
        end
      
      {:error, reason} -> {:error, {:dump_check_failed, reason}}
    end
  end

  defp file_is_recent?(filename) do
    # Check if file was created in the last 24 hours
    # This is a simplified check based on filename timestamp
    String.contains?(filename, Date.utc_today() |> Date.to_string())
  end
end
```

## Testing Strategies

### Test Helpers

```elixir
defmodule MyApp.ETSTestHelpers do
  def create_test_table(name, data \\ []) do
    table = :ets.new(name, [:set, :public])
    Enum.each(data, fn {key, value} -> :ets.insert(table, {key, value}) end)
    table
  end

  def assert_table_dumped(table_name) do
    log_dir = SickGrandma.Logger.log_directory_path()
    
    case File.ls(log_dir) do
      {:ok, files} ->
        table_files = Enum.filter(files, &String.contains?(&1, to_string(table_name)))
        assert length(table_files) > 0, "No dump file found for table #{table_name}"
      
      {:error, reason} ->
        flunk("Could not list log directory: #{inspect(reason)}")
    end
  end

  def cleanup_test_logs do
    log_dir = SickGrandma.Logger.log_directory_path()
    
    case File.ls(log_dir) do
      {:ok, files} ->
        test_files = Enum.filter(files, &String.contains?(&1, "test"))
        Enum.each(test_files, &File.rm(Path.join(log_dir, &1)))
      
      {:error, _} -> :ok
    end
  end
end
```

## Best Practices

1. **Use selective dumping** in production to avoid performance impact
2. **Implement proper error handling** and retry logic
3. **Set up log rotation** to prevent disk space issues
4. **Monitor dump frequency** and success rates
5. **Test dump functionality** in staging environments
6. **Consider async dumping** for non-critical use cases
7. **Implement health checks** to ensure system reliability

## Troubleshooting

### Common Issues

**Permission Errors**
```elixir
# Ensure proper directory permissions
log_dir = SickGrandma.Logger.log_directory_path()
File.chmod(log_dir, 0o755)
```

**Large Memory Usage**
```elixir
# Use selective dumping for large systems
MyApp.SelectiveDumper.dump_important_tables()
```

**Slow Performance**
```elixir
# Use async dumping
MyApp.AsyncDumper.dump_async()
```

For more troubleshooting tips, check the main documentation and consider opening an issue on the project repository.