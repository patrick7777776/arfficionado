#TODO: is target always the last? if so, return the target attribute name as well as the list of maps!
# -- ok, convention is that target/class is last;
# -- but for flexibility, we ought to return [attname-type] info, too!!!
defmodule Arfficionado.MapHandler do
  @moduledoc """
  Example handler module that collects a list of `{instance, weight}` tuples, where instance is a map of attribute-value pairs (corresponding to the attributes defined in the ARFF header) and weight is an integer. 
  """
  alias Arfficionado.Handler
  @behaviour Handler

  @impl Handler
  @doc """
  Produces initial state, ignores given argument.
  """
  def init(_), do: {nil, []}

  @impl Handler
  @doc """
  Extracts the attribute names and stores them in the upated state.
  """
  def attributes(attributes, {_, instances}) do
    keys = 
      attributes
      |> Enum.map(fn {:attribute, name, _type, _comment} -> name end)
      |> Enum.map(fn name -> String.to_atom(name) end)
    {:cont, {keys, instances}}
  end

  @impl Handler
  @doc """
  Converts the instance into a map of attribute-value pairs, and stores it and its instance weight in the updated state.
  """
  def instance(values, weight, _comment, {keys, instances}) do
    instance = 
      Enum.zip(keys, values)
      |> Enum.into(%{})
    {:cont, {keys, [{instance, weight} | instances]}}
  end

  @impl Handler
  @doc """
  Returns the list of `{instance, weight}`-tuples accumulated.
  """
  def close(_, {_keys, instances}), do: Enum.reverse(instances)
end
