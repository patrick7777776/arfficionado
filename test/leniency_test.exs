defmodule LeniencyTest do
  use ExUnit.Case
  import Arfficionado, only: [read: 3]

  test "omitting leading 0" do
    assert read(~s"""
      @relation foo
      @attribute a1 real
      @attribute a2 real
      @data
      1, .5
      """) == {:ok, [{[1.0, 0.5], 1}]}
  end

  test "omitting 0 for negative real" do
    assert read(~s"""
      @relation foo
      @attribute a1 real
      @attribute a2 real
      @data
      1, -.5
      """) == {:ok, [{[1.0, -0.5], 1}]}
  end

  test "float for int attribute" do
    # real, integer and numeric are all treated the same according to the arff spec, anyway
    assert read(~s"""
      @relation foo
      @attribute a1 integer
      @attribute a2 integer
      @data
      1, 3.1415 
      """) == {:ok, [{[1.0, 3.1415], 1}]}
  end

  defp read(s) do
    {:ok, stream} = StringIO.open(s)
    stream
    |> IO.binstream(:line)
    |> read(Arfficionado.ListHandler, [])
  end

  # leniency tests: float in int column; float: missing -0 , missing 0
  # extra [1-20] int ranges @attribute
  # no commas, just spaces

end
