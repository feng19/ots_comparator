#!/usr/bin/env elixir
case System.argv() do
  [config_path, instance_a, instance_b] ->
    Config.Reader.read!(config_path)
    |> Application.put_all_env()

    # Mix.install([{:ots_comparator, "~> 0.1.0"}])
    Mix.install([{:ots_comparator, path: "."}])

    OtsComparator.Cli.cli_compare(config_path, instance_a, instance_b)
  _ ->
    IO.puts("""
    Please pass three arguments, eg:
    ./ots_comparator.exs config_path instance_a instance_b
    """)
end