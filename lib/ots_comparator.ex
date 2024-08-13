defmodule OtsComparator do
  @moduledoc """
  Comparator for OTS(Aliyun Tablestore Database)
  """

  def compare(instance_a, instance_b) do
    {:ok, %{table_names: table_list_a}} = ExAliyunOts.list_table(instance_a)
    {:ok, %{table_names: table_list_b}} = ExAliyunOts.list_table(instance_b)

    diff = compare_list(table_list_a, table_list_b)

    table_content_diff =
      diff.both
      |> Task.async_stream(&task_compare_table(instance_a, instance_b, &1), timeout: :infinity)
      |> Stream.map(&elem(&1, 1))
      |> Enum.reject(&is_nil/1)

    if diff.count_diff == 0 and Enum.empty?(diff.list_diff) and Enum.empty?(table_content_diff) do
      :same
    else
      %{
        count: diff.count,
        count_diff: diff.count_diff,
        table_diff: diff.list_diff,
        table_content_diff: table_content_diff
      }
    end
  end

  defp task_compare_table(instance_a, instance_b, table) do
    case {compare_table(instance_a, instance_b, table),
          compare_table_index(instance_a, instance_b, table)} do
      {:same, :same} ->
        nil

      {:same, {index_diff, index_content_diff}} ->
        %{
          table: table,
          content_diff: :same,
          index_diff: index_diff,
          index_content_diff: index_content_diff
        }

      {content_diff, :same} ->
        %{
          table: table,
          content_diff: content_diff,
          index_diff: :same,
          index_content_diff: :same
        }

      {content_diff, {index_diff, index_content_diff}} ->
        %{
          table: table,
          content_diff: content_diff,
          index_diff: index_diff,
          index_content_diff: index_content_diff
        }
    end
  end

  def compare_table(instance_a, instance_b, table) do
    {:ok, schema_a} = ExAliyunOts.describe_table(instance_a, table)
    {:ok, schema_b} = ExAliyunOts.describe_table(instance_b, table)

    ignore_useless_field = &ignore_useless_field/1

    sort_by_name = fn list ->
      Stream.map(list, ignore_useless_field)
      |> Enum.sort_by(&Keyword.get(&1, :name))
    end

    simplified_schema = fn schema ->
      table_meta =
        schema.table_meta
        |> Map.delete(:table_name)
        |> Map.update!(:primary_key, sort_by_name)
        |> Map.update!(:index_meta, sort_by_name)
        |> Map.update!(:defined_column, sort_by_name)
        |> ignore_useless_field.()

      index_metas = Enum.map(schema.index_metas, ignore_useless_field)

      [table_meta: table_meta, index_metas: index_metas]
    end

    schema_a = simplified_schema.(schema_a)
    schema_b = simplified_schema.(schema_b)

    if schema_a == schema_b do
      :same
    else
      {schema_a, schema_b}
    end
  end

  def compare_table_index(instance_a, instance_b, table) do
    {:ok, %{indices: list_a}} = ExAliyunOts.list_search_index(instance_a, table)
    {:ok, %{indices: list_b}} = ExAliyunOts.list_search_index(instance_b, table)
    diff = compare_list(Enum.map(list_a, & &1.index_name), Enum.map(list_b, & &1.index_name))

    index_diff = %{
      count: diff.count,
      count_diff: diff.count_diff,
      index_diff: diff.list_diff
    }

    index_content_diff =
      diff.both
      |> Task.async_stream(
        fn index ->
          case compare_table_index(instance_a, instance_b, table, index) do
            :same -> nil
            content_diff -> %{index: index, content_diff: content_diff}
          end
        end,
        timeout: :infinity
      )
      |> Stream.map(&elem(&1, 1))
      |> Enum.reject(&is_nil/1)

    if diff.count_diff == 0 and Enum.empty?(diff.list_diff) and Enum.empty?(index_content_diff) do
      :same
    else
      {index_diff, index_content_diff}
    end
  end

  def compare_table_index(instance_a, instance_b, table, index) do
    {:ok, %{schema: schema_a}} = ExAliyunOts.describe_search_index(instance_a, table, index)
    {:ok, %{schema: schema_b}} = ExAliyunOts.describe_search_index(instance_b, table, index)

    ignore_useless_field = &ignore_useless_field/1

    simplified_index_sort = fn
      nil ->
        nil

      %{sorter: sorter_list} when is_list(sorter_list) ->
        Enum.map(
          sorter_list,
          fn sorter ->
            ignore_useless_field(sorter)
            |> Enum.map(fn {k, v} -> {k, ignore_useless_field(v)} end)
          end
        )
    end

    simplified_schema = fn schema ->
      schema
      |> Map.update!(
        :field_schemas,
        fn field_schemas ->
          Stream.map(field_schemas, ignore_useless_field)
          |> Enum.sort_by(&Keyword.get(&1, :field_name))
        end
      )
      |> Map.update!(:index_setting, ignore_useless_field)
      |> Map.update!(:index_sort, simplified_index_sort)
      |> ignore_useless_field()
    end

    schema_a = simplified_schema.(schema_a)
    schema_b = simplified_schema.(schema_b)

    if schema_a == schema_b do
      :same
    else
      {schema_a, schema_b}
    end
  end

  defp compare_list(list_a, list_b) do
    count_a = Enum.count(list_a)
    count_b = Enum.count(list_b)
    count_diff = abs(count_a - count_b)

    set_a = MapSet.new(list_a)
    set_b = MapSet.new(list_b)
    both_set = MapSet.intersection(set_a, set_b)
    only_on_a_set = MapSet.difference(set_a, set_b)
    only_on_b_set = MapSet.difference(set_b, set_a)

    list_diff =
      Enum.map(only_on_a_set, &{&1, :missing}) ++ Enum.map(only_on_b_set, &{:missing, &1})

    %{
      count: {count_a, count_b},
      count_diff: count_diff,
      both: MapSet.to_list(both_set),
      only_on_a: MapSet.to_list(only_on_a_set),
      only_on_b: MapSet.to_list(only_on_b_set),
      list_diff: list_diff
    }
  end

  defp ignore_useless_field(nil), do: nil

  defp ignore_useless_field(field_schema) do
    field_schema
    |> Map.from_struct()
    |> Map.drop([:__meta__])
    |> Enum.reject(fn {_k, v} -> is_nil(v) or v == [] end)
  end
end
