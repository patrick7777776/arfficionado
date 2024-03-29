defmodule OptionalCallbacksTest do
  use ExUnit.Case
  import Arfficionado, only: [read: 2]

  defmodule Recorder do
    @behaviour Arfficionado.Handler

    @impl Handler
    def init(_), do: []

    @impl Handler
    def line_comment(comment, state), do: {:cont, [{:line_comment, comment} | state]}

    @impl Handler
    def relation(name, comment, state), do: {:cont, [{:relation, name, comment} | state]}

    @impl Handler
    def attributes(attributes, state), do: {:cont, [{:attributes, attributes} | state]}

    @impl Handler
    def begin_data(comment, state), do: {:cont, [{:begin_data, comment} | state]}

    @impl Handler
    def instance(values, weight, comment, state),
      do: {:cont, [{:instance, values, weight, comment} | state]}

    @impl Handler
    def close(_, state), do: Enum.reverse(state)
  end

  test "comments are reported and optional callbacks are invoked" do
    assert read(~s"""
           % comment
           @relation foo % comment
           @attribute a1 integer % comment
           @attribute a2 integer % comment
           @data % comment
           1,2 % comment
           3,4, {5} % comment
           """) ==
             {:ok,
              [
                {:line_comment, "% comment\n"},
                {:relation, "foo", "% comment\n"},
                {:attributes,
                 [
                   {:attribute, "a1", :numeric, "% comment\n"},
                   {:attribute, "a2", :numeric, "% comment\n"}
                 ]},
                {:begin_data, "% comment\n"},
                {:instance, [1, 2], 1, "% comment\n"},
                {:instance, [3, 4], 5, "% comment\n"}
              ]}
  end

  defp read(s) do
    {:ok, stream} = StringIO.open(s)

    stream
    |> IO.binstream(:line)
    |> read(Recorder)
  end
end
