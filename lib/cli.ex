defmodule OtsComparator.Cli do
  @moduledoc false

  def cli_compare(config_path, instance_a, instance_b)
      when is_binary(config_path) and is_binary(instance_a) and is_binary(instance_b) do
    Config.Reader.read!(config_path)
    |> Application.put_all_env()

    Application.ensure_all_started(:ex_aliyun_ots)
    cli_compare(instance_a, instance_b)
  end

  def cli_compare(instance_a, instance_b) do
    OtsComparator.compare(
      String.to_existing_atom(instance_a),
      String.to_existing_atom(instance_b)
    )
    |> format(instance_a, instance_b)
  end

  def format(
        %{
          count: {count_a, count_b},
          count_diff: count_diff,
          table_diff: table_diff,
          table_content_diff: table_content_diff
        },
        instance_a,
        instance_b
      ) do
    [
      "",
      "Instance:#{instance_a}, count: #{count_a}",
      "Instance:#{instance_b}, count: #{count_b}",
      "Count diff: #{count_diff}",
      "",
      "#{instance_a} VS #{instance_b}",
      format_list_diff(table_diff),
      format_table_content_diff(table_content_diff)
    ]
    |> Stream.reject(&is_nil/1)
    |> Enum.intersperse("\n")
    |> IO.iodata_to_binary()
    |> IO.puts()
  end

  def format_list_diff([]), do: nil
  def format_list_diff(:same), do: nil

  def format_list_diff(list) do
    {lines_a, lines_b} = Enum.unzip(list)

    compare_view(
      Enum.map(lines_a, &to_string/1),
      Enum.map(lines_b, &to_string/1),
      :center
    )
  end

  def format_table_content_diff([]), do: nil

  def format_table_content_diff(list) do
    Stream.map(
      list,
      fn %{
           table: table,
           content_diff: content_diff,
           index_diff: index_diff,
           index_content_diff: index_content_diff
         } ->
        index_diff_lines =
          case index_diff do
            :same -> nil
            %{index_diff: index_diff} -> format_list_diff(index_diff)
          end

        index_content_diff_lines =
          case index_content_diff do
            :same ->
              []

            [] ->
              []

            _ ->
              Enum.map(index_content_diff, &format_index_content/1) |> Enum.intersperse("\n")
          end

        [
          "\n#{IO.ANSI.blue()}Table name: #{table}#{IO.ANSI.reset()}\n",
          format_table_content(content_diff),
          index_diff_lines | index_content_diff_lines
        ]
        |> Stream.reject(&is_nil/1)
        |> Enum.intersperse("\n")
      end
    )
    |> Stream.reject(&is_nil/1)
    |> Enum.intersperse("\n")
  end

  def format_table_content(:same), do: "#{IO.ANSI.green()}Fields: same#{IO.ANSI.reset()}"

  def format_table_content({table_a, table_b}) do
    compare_view(
      format_table(table_a),
      format_table(table_b),
      :left,
      60
    )
  end

  def format_table(table) do
    table
    |> inspect(pretty: true, limit: :infinity, width: 58)
    |> String.split("\n")
  end

  def format_index_content(:same), do: "#{IO.ANSI.green()}Indexes: same#{IO.ANSI.reset()}"

  def format_index_content(%{index: index, content_diff: {index_a, index_b}}) do
    [
      "\n#{IO.ANSI.blue()}Index name: #{index}#{IO.ANSI.reset()}\n\n",
      compare_view(
        format_table_index(index_a),
        format_table_index(index_b),
        :left,
        60
      )
    ]
  end

  def format_table_index(table_index) do
    table_index
    |> inspect(pretty: true, limit: :infinity, width: 58)
    |> String.split("\n")
  end

  defp compare_view(lines_a, lines_b, align) do
    max =
      max(
        Enum.max_by(lines_a, &String.length/1, fn -> 0 end) |> String.length(),
        Enum.max_by(lines_a, &String.length/1, fn -> 0 end) |> String.length()
      )

    compare_view(lines_a, lines_b, align, max)
  end

  defp compare_view(lines_a, lines_b, align, max) do
    len_a = length(lines_a)
    len_b = length(lines_b)
    max_len = max(len_a, len_b)

    Enum.zip_with(
      lines_a ++ List.duplicate("", max_len - len_a),
      lines_b ++ List.duplicate("", max_len - len_b),
      fn
        left, left ->
          content = padding_space(left, max, align)
          [content, " | ", content]

        left, right ->
          [
            IO.ANSI.red(),
            padding_space(left, max, align),
            " | ",
            padding_space(right, max, align),
            IO.ANSI.reset()
          ]
      end
    )
    |> Enum.intersperse("\n")
  end

  defp padding_space(content, max, :left) do
    String.pad_trailing(content, max)
  end

  defp padding_space(content, max, :center) do
    len = String.length(content)
    left_spaces = div(max - len, 2) + div(len, 2)

    String.pad_leading(content, left_spaces)
    |> String.pad_trailing(max)
  end

  defp padding_space(content, max, :right) do
    String.pad_leading(content, max)
  end
end
