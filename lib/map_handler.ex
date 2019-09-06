defmodule Arfficionado.MapHandler do
  alias Arfficionado.Handler
  @behaviour Handler

  @impl Handler
  def init(nil), do: {nil, []}
  def init(instances) when is_list(instances), do: {instances, []}

  @impl Handler
  def attributes(attributes, {_, instances}) do
    keys = 
      attributes
      |> Enum.map(fn {:attribute, name, _type, _comment} -> name end)
      |> Enum.map(fn name -> String.to_atom(name) end)
    {:cont, {keys, instances}}
  end

  @impl Handler
  def instance(values, weight, _comment, {keys, instances}) do
    instance = 
      Enum.zip(keys, values)
      |> Enum.into(%{})
    {:cont, {keys, [{instance, weight} | instances]}}
  end

  @impl Handler
  def close(_, {_keys, instances}), do: Enum.reverse(instances)
end
