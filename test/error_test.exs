defmodule ErrorTest do
  use ExUnit.Case
  import Arfficionado, only: [read: 2]

  defmodule ETHandler do
    alias Arfficionado.Handler
    @behaviour Handler

    @impl Handler
    def init(state), do: state

    @impl Handler
    def attributes(_attributes, state), do: {:cont, state}

    @impl Handler
    def instance(_values, _weight, _comment, state), do: {:cont, state}

    @impl Handler
    def close(:error, _state), do: :closed
    def close(_, _state), do: :status_should_have_been_error
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

  test "instance: unexpected tokens after weight" do
    assert read(~s"""
           @relation foo
           @attribute a1 integer
           @data
           1, {42} hello
           """) == {:error, "Line 4: Unexpected: [{:string, \"hello\"}, :line_break]", :closed}
  end

  test "instance: unexpected tokens" do
    assert read(~s"""
           @relation foo
           @attribute a1 integer
           @data
           1 hello
           """) == {:error, "Line 4: Unexpected: [{:string, \"hello\"}, :line_break]", :closed}
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
           """) ==
             {:error, "Line 7: Cannot parse 2012-10-05 as ISO-8601 date for attribute a2.",
              :closed}
  end

  test "instance: numeric 0." do
    assert read(~s"""
           @relation foo
           @attribute a1 numeric
           @attribute a2 numeric
           @data
           1.0, 2.
           """) ==
             {:error,
              "Line 5: Nonempty remainder . when parsing 2. as integer/real for attribute a2.",
              :closed}
  end

  test "instance: unclosed quote" do
    assert read(~s"""
           @relation foo
           @attribute n numeric
           @attribute text string
           @data
           1, "line\\nline2"
           2, "in \\\"quotes\\\" ..."
           3, "boom
           4, "the end"
           """) ==
             {:error, "Line 7: \"boom\n is missing closing quote for attribute text.", :closed}
  end

  test "@relation unclosed quote" do
    assert read(~s"""
           @relation "foo bar
           @attribute a1 integer
           @attribute a2 integer
           @data
           1, 2
           """) == {:error, "Line 1: Unclosed quote in @relation.", :closed}
  end

  test "@relation followed by unexpected tokens" do
    assert read(~s"""
           @relation foo bar
           """) == {:error, "Line 1: Unexpected: [{:string, \"bar\"}, :line_break]", :closed}
  end

  test "@attribute unclosed quote" do
    assert read(~s"""
           @relation foo
           @attribute "a 1 1" integer
           @attribute "a 1 2 integer
           @data
           1, 2
           """) == {:error, "Line 3: Unclosed quote in @attribute.", :closed}
  end

  test "@attribute (integer) followed by unexpected tokens" do
    assert read(~s"""
           @relation foo
           @attribute a1 integer, which must be a prime
           @data
           1
           """) ==
             {:error,
              "Line 2: Unexpected: [:comma, {:string, \"which\"}, {:string, \"must\"}, {:string, \"be\"}, {:string, \"a\"}, {:string, \"prime\"}, :line_break]",
              :closed}
  end

  test "@attribute (nominal) followed by unexpected tokens" do
    assert read(~s"""
           @relation foo
           @attribute a1 {yay, nay} maybe
           @data
           yay 
           """) == {:error, "Line 2: Unexpected: [{:string, \"maybe\"}, :line_break]", :closed}
  end

  test "@attribute (string) followed by unexpected tokens" do
    assert read(~s"""
           @relation foo
           @attribute a1 string 1234
           @data
           yay 
           """) == {:error, "Line 2: Unexpected: [{:string, \"1234\"}, :line_break]", :closed}
  end

  test "@attribute (date) followed by unexpected tokens" do
    assert read(~s"""
           @relation foo
           @attribute a1 date 'yyyy-mm-dd' yo
           @data
           1
           """) == {:error, "Line 2: Unexpected: [{:string, \"yo\"}, :line_break]", :closed}
  end

  test "@data followed by unexpected tokens" do
    assert read(~s"""
           @relation foo
           @attribute a1 integer
           @attribute a2 integer
           @data schmata
           1, 2
           """) == {:error, "Line 4: Unexpected: [{:string, \"schmata\"}, :line_break]", :closed}
  end

  test "duplicated attribute name" do
    assert read(~s"""
           @relation foo
           @attribute a1 integer
           @attribute a1 string
           @data
           1, a
           """) == {:error, "Line 3: Duplicate attribute name a1.", :closed}
  end

  test "header: relational attributes not supported (yet)" do
    assert read(~s"""
           @relation relational
           @attribute relex relational
             @attribute a numeric
             @attribute b numeric
           @end relex
           @data
           1 hello
           """) ==
             {:error, "Line 2: Attribute type relational is not currently supported.", :closed}
  end

  test "sparse format not supported (yet)" do
    assert read(~s"""
           @relation sparse
           @attribute a numeric
           @attribute b numeric
           @attribute c numeric
           @data
           {1 1, 3 3}
           {2 2, 3 3}
           """) == {:error, "Line 6: Sparse format is not currently supported.", :closed}
  end

  # non-iso 8601 date format: reject for now

  defp read(s) do
    {:ok, stream} = StringIO.open(s)

    stream
    |> IO.binstream(:line)
    |> read(ETHandler)
  end
end
