defmodule Arfficionado.ListHandler do

    alias Arfficionado.Handler
    @behaviour Handler

    @impl Handler
    def line_comment(_comment, instances), do: {:cont, instances}

    @impl Handler
    def relation(_name, _comment, instances), do: {:cont, instances}

    @impl Handler
    def attributes(_attributes, instances), do: {:cont, instances}

    @impl Handler
    def begin_data(_comment, instances), do: {:cont, instances}

    @impl Handler
    def instance(values, weight, _comment, instances), do: {:cont, [{values, weight} | instances]}

    @impl Handler
    def close(instances), do: Enum.reverse(instances)

end
