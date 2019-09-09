defmodule CastTest do
  use ExUnit.Case
  import Arfficionado, only: [cast: 3]

  @attributes [
    {:attribute, "name", :numeric, nil},
    {:attribute, "name", :numeric, nil},
    {:attribute, "name", {:nominal, ["yes", "no", "MAYBE?!"]}, nil},
    {:attribute, "name", :string, nil},
    {:attribute, "name", {:date, :iso_8601}, nil}
  ]


  test "cast" do
    {:ok, dt, _} = DateTime.from_iso8601("2019-08-28T11:23:18Z")

    assert cast(
             {:raw_instance,
              ["1", "1.23", "yes", "Blah blah blah!", "2019-08-28T11:23:18Z"], 1, nil},
              @attributes,
              &Arfficionado.custom_date_parse/2

           ) == {:instance, [1, 1.23, :yes, "Blah blah blah!", dt], 1, nil}
  end

  test "cast missing" do
    assert cast(
             {:raw_instance, [:missing, :missing, :missing, :missing, :missing], 7,
              nil},
             @attributes, &Arfficionado.custom_date_parse/2

           ) == {:instance, [:missing, :missing, :missing, :missing, :missing], 7, nil}
  end

  test "cast unexpected nominal value" do
    assert cast({:raw_instance, ["a"], 2, nil}, [
             {:attribute, "name", {:nominal, ["b", "c"]}, nil}], &Arfficionado.custom_date_parse/2

           ) == {:error, "Unexpected nominal value a for attribute name."}
  end

  test "cast unexpected numeric value" do
    assert cast({:raw_instance, ["a"], 2, nil}, [{:attribute, "name", :numeric, nil}], &Arfficionado.custom_date_parse/2
    ) ==
             {:error, "Cannot cast a to integer/real for attribute name."}
  end

  test "cast custom date format" do
    assert cast({:raw_instance, ["20190502"], 1, nil}, [{:attribute, "funky_date", {:date, "yyyymmdd"}, nil}], &Arfficionado.custom_date_parse/2
    ) == {:error, "Attribute funky_date: date format yyyymmdd not supported; please pass a custom date parsing function."}
  end

  # TODO: now the same but with a custom parsing function...

end
