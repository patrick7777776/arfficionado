defmodule Arfficionado.ListHandler do
  @moduledoc """
  Example handler module that collects a list of `{instance, weight}` tuples, where instance is a list of values (corresponding to the attributes defined in the ARFF header) and weight is an integer. Use `[]` as the initial state.
  """

  alias Arfficionado.Handler
  @behaviour Handler

  @impl Handler
  def attributes(_attributes, instances), do: {:cont, instances}

  @impl Handler
  def instance(values, weight, _comment, instances), do: {:cont, [{values, weight} | instances]}

  @impl Handler
  def close(instances), do: Enum.reverse(instances)

end
