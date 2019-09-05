defmodule ArfficionadoTest do
  use ExUnit.Case
  import Arfficionado, only: [read: 3]

  doctest Arfficionado

  defmodule TestHandler do
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

  test "a fine short arff file" do
    assert read(~s"""
      @relation foo
      @attribute a1 integer
      @attribute a2 integer
      @data
      1,2
      3,4, {5}
      """) == {:ok, [{[1, 2], 1}, {[3, 4], 5}]}
  end

  defp read(s) do
    {:ok, stream} = StringIO.open(s)
    stream
    |> IO.binstream(:line)
    |> read(TestHandler, [])
  end

end
