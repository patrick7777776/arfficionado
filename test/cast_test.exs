defmodule CastTest do
  use ExUnit.Case
  import Arfficionado, only: [cast: 2]

  @attributes [
    {:attribute, "name", :integer, nil},
    {:attribute, "name", :real, nil},
    {:attribute, "name", :numeric, nil},
    {:attribute, "name", {:nominal, ["yes", "no", "MAYBE?!"]}, nil},
    {:attribute, "name", :string, nil},
    {:attribute, "name", {:date, :iso_8601}, nil}
  ]

  test "cast" do
    {:ok, dt, _} = DateTime.from_iso8601("2019-08-28T11:23:18Z")

    assert cast(
             {:raw_instance,
              ["1", "1.23", "4.5", "yes", "Blah blah blah!", "2019-08-28T11:23:18Z"], 1, nil},
             @attributes
           ) == {:instance, [1, 1.23, 4.5, :yes, "Blah blah blah!", dt], 1, nil}
  end

  test "cast missing" do
    assert cast(
             {:raw_instance, [:missing, :missing, :missing, :missing, :missing, :missing], 7,
              nil},
             @attributes
           ) == {:instance, [:missing, :missing, :missing, :missing, :missing, :missing], 7, nil}
  end

  test "cast unexpected nominal value" do
    assert_raise ArgumentError, fn ->
      cast({:raw_instance, ["a"], 2, nil}, [{:attribute, "name", {:nominal, ["b", "c"]}, nil}])
    end
  end

  test "cast unexpected numeric value" do
    assert_raise MatchError, fn ->
      cast({:raw_instance, ["a"], 2, nil}, [{:attribute, "name", :numeric, nil}])
    end
  end

end
