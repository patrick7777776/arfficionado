defmodule ParseTest do
  use ExUnit.Case
  import Arfficionado, only: [parse: 1, tokenize: 1]

  test "empty line" do
    assert p("   \n") == :empty_line
  end

  test "line comment" do
    assert p("% line comment\n") == {:comment, "% line comment\n"}
  end

  test "@relation some_relation" do
    assert p("@relation some_relation\n") == {:relation, "some_relation", nil}

    assert p("@relation some_relation % some_comment\n") ==
             {:relation, "some_relation", "% some_comment\n"}
  end

  test "@attribute numeric/real/integer" do
    assert p("@attribute name numeric\n") == {:attribute, "name", :numeric, nil}

    assert p("@attribute name real % get real\n") ==
             {:attribute, "name", :numeric, "% get real\n"}

    assert p("@attribute name integer\n") == {:attribute, "name", :numeric, nil}
  end

  test "@attribute nominal" do
    assert p("@attribute name {Yes, No, Maybe}\n") ==
             {:attribute, "name", {:nominal, ["Yes", "No", "Maybe"]}, nil}

    assert p(~s[@attribute name {"top left", "bottom right"} % corner\n]) ==
             {:attribute, "name", {:nominal, ["top left", "bottom right"]}, "% corner\n"}
  end

  test "@attribute string" do
    assert p("@attribute name string\n") == {:attribute, "name", :string, nil}

    assert p("@attribute name string % description\n") ==
             {:attribute, "name", :string, "% description\n"}
  end

  test "@attribute date" do
    assert p("@attribute name date\n") == {:attribute, "name", {:date, :iso_8601}, nil}

    assert p("@attribute name date % timestamp\n") ==
             {:attribute, "name", {:date, :iso_8601}, "% timestamp\n"}

    assert p(~s[@attribute name date "yyyy-MM-dd'T'HH:mm:ss"\n]) ==
             {:attribute, "name", {:date, "yyyy-MM-dd'T'HH:mm:ss"}, nil}

    assert p(~s[@attribute name date "yyyy-MM-dd'T'HH:mm:ss" % java.text.SimpleDateFormat\n]) ==
             {:attribute, "name", {:date, "yyyy-MM-dd'T'HH:mm:ss"},
              "% java.text.SimpleDateFormat\n"}
  end

  test "@attribute relational" do
    assert p("@attribute name relational\n") == {:attribute, "name", :relational, nil}

    assert p("@attribute name relational % futuristic!\n") ==
             {:attribute, "name", :relational, "% futuristic!\n"}

    assert p("@end name\n") == {:end, "name", nil}
    assert p("@end name % blah\n") == {:end, "name", "% blah\n"}
  end

  test "@data" do
    assert p("@data\n") == {:data, nil}
    assert p("@data % instances\n") == {:data, "% instances\n"}
  end

  test "instances" do
    assert p(~s[1\ta\t" %{} "\n]) == {:raw_instance, ["1", "a", " %{} "], 1, nil}

    assert p(~s[ 1 \t a\t" ,,, " % comment\n]) ==
             {:raw_instance, ["1", "a", " ,,, "], 1, "% comment\n"}

    assert p(~s[1,2,3\n]) == {:raw_instance, ["1", "2", "3"], 1, nil}
    assert p(~s[1,2,3, {5}\n]) == {:raw_instance, ["1", "2", "3"], 5, nil}
    assert p(~s[1,?,3, {5}\n]) == {:raw_instance, ["1", :missing, "3"], 5, nil}
    assert p(~s[1,2,3, {5} %blah \n]) == {:raw_instance, ["1", "2", "3"], 5, "%blah \n"}
    assert p(~s[1\t 2\t  3  \t {5}\n]) == {:raw_instance, ["1", "2", "3"], 5, nil}
    assert p(~s[1   \t2\t 3 \t{5} %blah  \n]) == {:raw_instance, ["1", "2", "3"], 5, "%blah  \n"}
  end

  defp p(text) do
    text
    |> tokenize()
    |> parse()
  end
end
