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
      """) == {:ok, [{[1, -0.5], 1}]}
  end

  test "float for int attribute" do
    # real, integer and numeric are all treated the same according to the arff spec, anyway
    assert read(~s"""
      @relation foo
      @attribute a1 integer
      @attribute a2 integer
      @data
      1, 3.1415 
      """) == {:ok, [{[1, 3.1415], 1}]}
  end

  test "no linebreak in last line" do
    assert read("@relation foo\n@attribute a1 integer\n@attribute a2 integer\n@data\n1, 2") == {:ok, [{[1, 2], 1}]}
  end

  test "tab-separated comment" do
    assert read(~s"""
      @relation foo \t% comment
      @attribute a1 integer\t\t\t% comment
      @attribute a2 integer\t  % comment
      @data\t \t \t \t%comment
      1, 2\t%comment
      1, 2 \t %comment
      1, 2 \t  \t %comment
      1, 2\t\t % comment
      """) == {:ok, [{[1, 2], 1}, {[1, 2], 1}, {[1, 2], 1}, {[1, 2], 1}]}
  end

  test ",, (instead of ?) to indicate missing value" do
    assert read(~s"""
      @relation foo
      @attribute a1 numeric
      @attribute a2 numeric
      @attribute a3 numeric
      @data
      1,,3 
      ,2,3
      """) == {:ok, [{[1, :missing, 3], 1}, {[:missing, 2, 3], 1}]}
  end


  defp read(s) do
    {:ok, stream} = StringIO.open(s)
    stream
    |> IO.binstream(:line)
    |> read(Arfficionado.ListHandler, [])
  end

  # extra [1-20] int ranges @attribute
  # no commas, just spaces

end
