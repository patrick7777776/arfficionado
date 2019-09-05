defmodule ArfficionadoTest do
  use ExUnit.Case
  import Arfficionado, only: [read: 3]

  doctest Arfficionado

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
    |> read(Arfficionado.ListHandler, [])
  end
end
