defmodule ErrorTest do
  use ExUnit.Case
  import Arfficionado, only: [read: 3]

  defmodule ETHandler do
    alias Arfficionado.Handler
    @behaviour Handler

    @impl Handler
    def line_comment(_comment, state), do: {:cont, state}

    @impl Handler
    def relation(_name, _comment, state), do: {:cont, state}

    @impl Handler
    def attributes(_attributes, state), do: {:cont, state}

    @impl Handler
    def begin_data(_comment, state), do: {:cont, state}

    @impl Handler
    def instance(_values, _weight, _comment, state), do: {:cont, state}

    @impl Handler
    def close(state), do: :closed
  end

  test "@relation expected" do
    assert read(~s"""
      % missing @relation
      @attribute a1 integer
      @attribute a2 integer
      @data
      1,2
      """) == {:error, "Line 2: Expected @relation.", :closed}

    assert read(~s"""
      % missing @relation
      @data
      1,2
      """) == {:error, "Line 2: Expected @relation.", :closed}

    assert read(~s"""
      % missing @relation
      1,2
      """) == {:error, "Line 2: Expected @relation.", :closed}

    assert read(~s"""
      % missing @relation
      """) == {:error, "Line 2: Expected @relation.", :closed}

    assert read("") == {:error, "Line 1: Expected @relation.", :closed}
  end

  test "@attribute expected" do
    assert read(~s"""
      @relation foo
      % missing @attribute
      @data
      1,2
      """) == {:error, "Line 3: Expected @attribute.", :closed}

    assert read(~s"""
      @relation foo
      1,2
      """) == {:error, "Line 2: Expected @attribute.", :closed}

    assert read(~s"""
      @relation foo
      """) == {:error, "Line 2: Expected @attribute.", :closed}

    assert read("@relation foo") == {:error, "Line 2: Expected @attribute.", :closed}

    assert read(~s"""
      @relation foo
      @relation bar
      """) == {:error, "Line 2: Expected @attribute.", :closed}
  end

  test "@data expected" do
    assert read(~s"""
      @relation foo
      @attribute a1 integer
      @attribute a2 integer
      % missing @data
      1,2
      """) == {:error, "Line 5: Expected @attribute or @data.", :closed}

    assert read(~s"""
      @relation foo
      @attribute a1 integer
      """) == {:error, "Line 3: Expected @attribute or @data.", :closed}
  end

  test "instance: too few values" do
    assert read(~s"""
      @relation foo
      @attribute a1 integer
      @attribute a2 integer
      @data
      1,2
      3 % one too few
      """) == {:error, "Line 6: Fewer values than attributes.", :closed}
  end

  test "instance: too many values" do
    assert read(~s"""
      @relation foo
      @attribute a1 integer
      @attribute a2 integer
      @data
      1,2,3 % one too many
      3,4
      """) == {:error, "Line 5: More values than attributes.", :closed}
  end

  test "instance: type error int-string" do
    assert read(~s"""
      @relation foo
      @attribute a1 integer
      @attribute a2 integer
      @data
      1, two
      """) == {:error, "Line 5: Cannot cast two to integer/real for attribute a2.", :closed}
  end

  test "instance: type error real-string" do
    assert read(~s"""
      @relation foo
      @attribute a1 real
      @attribute a2 real
      @data
      1, two
      """) == {:error, "Line 5: Cannot cast two to integer/real for attribute a2.", :closed}
  end

  test "instance: type error numeric-string" do
    assert read(~s"""
      @relation foo
      @attribute a1 numeric
      @attribute a2 numeric
      @data
      1, two
      """) == {:error, "Line 5: Cannot cast two to integer/real for attribute a2.", :closed}
  end

  test "instance: type error nominal-unexpected" do
    assert read(~s"""
      @relation foo
      @attribute a1 integer
      @attribute a2 {yes, no}
      @data
      1, yes
      2, no
      3, maybe
      """) == {:error, "Line 7: Unexpected nominal value maybe for attribute a2.", :closed}
  end

  test "instance: type error wrong format for ISO-8601 date" do
    assert read(~s"""
      @relation foo
      @attribute a1 integer
      @attribute a2 date
      @data
      1, 2018-06-03T10:38:28Z
      2, 2019-09-03T10:38:28+00:00
      3, 2012-10-05
      """) == {:error, "Line 7: Cannot parse 2012-10-05 as ISO-8601 date for attribute a2.", :closed}
  end

  defp read(s) do
    {:ok, stream} = StringIO.open(s)
    stream
    |> IO.binstream(:line)
    |> read(ETHandler, nil)
  end

  # leniency tests: float in int column; float: missing -0 , missing 0
  # extra [1-20] int ranges @attribute
  # no commas, just spaces

end
