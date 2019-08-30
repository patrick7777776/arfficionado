defmodule TokenizeTest do
  use ExUnit.Case
  import Arfficionado, only: [tokenize: 1]

  test "line comment" do
    assert tokenize("% comment") == [{:comment, "% comment"}]
    assert tokenize("   % comment") == [{:comment, "% comment"}]
  end

  test "line break" do
    assert tokenize("\n") == [:line_break]
    assert tokenize("   \n") == [:line_break]
  end

  test "@relation name" do
    assert tokenize("@relation name\n") == [
             {:string, "@relation"},
             {:string, "name"},
             :line_break
           ]

    assert tokenize("@relation name \n") == [
             {:string, "@relation"},
             {:string, "name"},
             :line_break
           ]
  end

  test "@attribute name basic_type" do
    assert tokenize("@attribute name type\n") == [
             {:string, "@attribute"},
             {:string, "name"},
             {:string, "type"},
             :line_break
           ]
  end

  test "@attribute name enum" do
    assert tokenize("@attribute name {c1,c_2,c/3,c(4)}\n") == [
             {:string, "@attribute"},
             {:string, "name"},
             :open_curly,
             {:string, "c1"},
             :comma,
             {:string, "c_2"},
             :comma,
             {:string, "c/3"},
             :comma,
             {:string, "c(4)"},
             :close_curly,
             :line_break
           ]
  end

  test "@attribute name date format" do
    assert tokenize(~s[@ATTRIBUTE timestamp DATE "yyyy-MM-dd HH:mm:ss"\n]) == [
             {:string, "@ATTRIBUTE"},
             {:string, "timestamp"},
             {:string, "DATE"},
             {:string, "yyyy-MM-dd HH:mm:ss"},
             :line_break
           ]
  end

  test "@attribute name relational" do
    assert tokenize("@attribute name relational\n") == [
             {:string, "@attribute"},
             {:string, "name"},
             {:string, "relational"},
             :line_break
           ]

    assert tokenize("@end name\n") == [{:string, "@end"}, {:string, "name"}, :line_break]
  end

  test "@data" do
    assert tokenize("@data\n") == [{:string, "@data"}, :line_break]
  end

  test "example data" do
    assert tokenize("a,-1,b_2/3\n") == [
             {:string, "a"},
             :comma,
             {:string, "-1"},
             :comma,
             {:string, "b_2/3"},
             :line_break
           ]

    assert tokenize("a ,   -1   \tb_2/3   \n") == [
             {:string, "a"},
             :comma,
             {:string, "-1"},
             :tab,
             {:string, "b_2/3"},
             :line_break
           ]
  end

  test "example data - missing value" do
    assert tokenize("a,?,c\n") == [
             {:string, "a"},
             :comma,
             :missing,
             :comma,
             {:string, "c"},
             :line_break
           ]

    assert tokenize("a, ?,c\n") == [
             {:string, "a"},
             :comma,
             :missing,
             :comma,
             {:string, "c"},
             :line_break
           ]

    assert tokenize("a,? ,c\n") == [
             {:string, "a"},
             :comma,
             :missing,
             :comma,
             {:string, "c"},
             :line_break
           ]

    assert tokenize("a, ? ,c\n") == [
             {:string, "a"},
             :comma,
             :missing,
             :comma,
             {:string, "c"},
             :line_break
           ]
  end

  test "example data - quotes" do
    assert tokenize(~s{a, " b c d "\n}) == [
             {:string, "a"},
             :comma,
             {:string, " b c d "},
             :line_break
           ]

    assert tokenize(~s["?", 'b%c\td\n{}'\n]) == [
             {:string, "?"},
             :comma,
             {:string, "b%c\td\n{}"},
             :line_break
           ]

    assert tokenize(~s[""\n]) == [{:string, ""}, :line_break]
  end

end
