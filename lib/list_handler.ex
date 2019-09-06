# rename?!?!
defmodule Arfficionado.ListHandler do
  @moduledoc """
  Trivial example handler module that collects a list of `{instance, weight}` tuples, where instance is a list of values (corresponding to the attributes defined in the ARFF header) and weight is an integer. 
  """

  alias Arfficionado.Handler
  @behaviour Handler

  @impl Handler
  @doc """
  Produces initial state, ignores given argument.
  """
  def init(_), do: []

  @impl Handler
  @doc """
  Returns the instance list (i.e. the handler state) as is; the attributes are ignored.
  """
  def attributes(_attributes, instances), do: {:cont, instances}

  @impl Handler
  @doc """
  Appends `{values, weight}` to the instance list (i.e. the handler state) and returns it. The optional comment is ignored.
  """
  def instance(values, weight, _comment, instances), do: {:cont, [{values, weight} | instances]}

  @impl Handler
  @doc """
  Returns the collected instances. 
  """
  def close(_, instances), do: Enum.reverse(instances)
end
