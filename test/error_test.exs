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

  test "too few values" do
    assert read(~s"""
      @relation foo
      @attribute a1 integer
      @attribute a2 integer
      @data
      1,2
      3 % one too few
      """) == {:error, "Line 6: Fewer values than attributes.", :closed}
  end

  test "too many values" do
    assert read(~s"""
      @relation foo
      @attribute a1 integer
      @attribute a2 integer
      @data
      1,2,3 % one too many
      3,4
      """) == {:error, "Line 5: More values than attributes.", :closed}
  end

  defp read(s) do
    {:ok, stream} = StringIO.open(s)
    stream
    |> IO.binstream(:line)
    |> read(ETHandler, nil)
  end

  # {:error, reason} | {:ok, state}
  #

  # missing header parts -- complain
  # duplicated header parts; repeated header parts; ...
  # too many / too few values -- line no + good message
  # cast errors: value with wrong type
  # 

  # when error is encountered, must still call close() !


end
