# OTS-Comparator

**Comparator for OTS(Aliyun Tablestore Database)**

- [x] 对比两个实例 表数量
- [x] 对比两个实例 表的字段
- [x] 对比两个实例 表的多元索引

## Usage

`ots_comparator.exs`:

```elixir
#!/usr/bin/env elixir
case System.argv() do
  [config_path, instance_a, instance_b] ->
    Config.Reader.read!(config_path)
    |> Application.put_all_env()

    Mix.install([{:ots_comparator, "~> 0.1.0"}])

    OtsComparator.Cli.cli_compare(config_path, instance_a, instance_b)
  _ -> 
    IO.puts("""
    Please pass three arguments, eg:
    ./ots_comparator.exs config_path instance_a instance_b
    """)
end
```

`config/config.exs`:

```elixir
import Config

config :ex_aliyun_ots, instances: [:dev_instance, :prod_instance]

config :ex_aliyun_ots, :dev_instance,
  name: "dev-instance",
  endpoint: "https://dev-instance.cn-shenzhen.ots.aliyuncs.com",
  access_key_id: "access_key_id",
  access_key_secret: "access_key_secret"

config :ex_aliyun_ots, :prod_instance,
  name: "prod-instance",
  endpoint: "https://prod-instance.cn-shenzhen.ots.aliyuncs.com",
  access_key_id: "access_key_id",
  access_key_secret: "access_key_secret"
```

exec:

```shell
chmod +x ots_comparator.exs 
./ots_comparator.exs config/config.exs dev_instance prod_instance
```

or

```shell
elixir ots_comparator.exs config/config.exs dev_instance prod_instance
```

## Copyright and License

Copyright (c) 2024 feng19

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at [http://www.apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0)

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.