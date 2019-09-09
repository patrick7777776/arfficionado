#add date to example?
defmodule Arfficionado do
  @moduledoc """
  Reader for [ARFF (Attribute Relation File Format)](https://waikato.github.io/weka-wiki/arff/) data.
  Adaptable to application-specific needs through custom handler behaviour implementations.

  ```
  {:ok, instances} =
    File.stream!("data.arff")
    |> Arfficionado.read(Arfficionado.ListHandler)
  ```

  Current limitations:
  - ISO-8601 is the only supported `date` format
  - no support for attributes of type `relational`
  - no support for sparse format
  """

  @doc ~s"""
  Parses an enumerable/stream of ARFF lines, invokes handler callbacks and returns final handler state.

  Initializes handler state by invoking `init(arg)` and then modifies the state through invocations of the other `handler` callbacks.
  Returns `{:ok, final_handler_state}` or `{:error, reason, final_handler_state}`. 



  ## Examples

  Using `Arfficionado.ListHandler` to collect the instances (with weights) from the following ARFF input:

  ```
  @relation example
  @attribute a1 numeric
  @attribute a2 string
  @attribute a3 {red, blue}
  @data
  1,      Hello,         red
  2,      "Hi there!",   blue
  ?,      ?,             ?          % missing values
  3.1415, 'What\\'s up?', red        % escaped '
  4,      abc,           blue, {7}  % instance weight 7
  ```

      iex> [
      ...>   ~s[@relation example],
      ...>   ~s[@attribute a1 numeric],
      ...>   ~s[@attribute a2 string],
      ...>   ~s[@attribute a3 {red, blue}],
      ...>   ~s[@data],
      ...>   ~s[1,      Hello,            red],
      ...>   ~s[2,      "Hi there!",      blue],
      ...>   ~s[?,      ?,                ?       % missing values],
      ...>   ~s[3.1415, 'What\\\\'s up?', red       % escaped '],
      ...>   ~s[4,      abc,           blue, {7}  % instance weight 7] 
      ...> ] |>
      ...> Arfficionado.read(Arfficionado.ListHandler)
      {:ok, [
        {[1, "Hello", :red], 1},
        {[2, "Hi there!", :blue], 1},
        {[:missing, :missing, :missing], 1}, 
        {[3.1415, "What's up?", :red], 1}, 
        {[4, "abc", :blue], 7}
      ]}
  """
  @spec read(Enumerable.t(), Arfficionado.Handler.t(), any()) ::
          {:ok, Arfficionado.Handler.state()} | {:error, String.t(), Arfficionado.Handler.state()}
  def read(arff, handler, arg \\ nil, parse_date \\ &custom_date_parse/2) do
    #TODO: pass down the parse_date function...
    initial_handler_state = handler.init(arg)

    case Enum.reduce_while(
           arff,
           {handler, initial_handler_state, :"@relation", [], parse_date, 1},
           &process_line/2
         ) do
      {_, {:error, reason, handler_state}, _, _, _, line_number} ->
        final_state = handler.close(:error, handler_state)
        {:error, ~s"Line #{line_number}: #{reason}", final_state}

      {_, handler_state, stage, _, _, line_number} when stage != :instance ->
        final_state = handler.close(:error, handler_state)
        {:error, ~s"Line #{line_number}: Expected #{Atom.to_string(stage)}.", final_state}

      {_, handler_state, _, _, _, _} ->
        final_state = handler.close(:ok, handler_state)
        {:ok, final_state}
    end
  end

  defp process_line(line, {handler, handler_state, stage, attributes, date_parse, line_number}) do
    parsed =
      line
      |> tokenize()
      |> parse()

    {cont_or_halt, updated_handler_state, updated_stage, updated_attributes, updated_line_number} =
      case parsed do
        :empty_line ->
          {:cont, handler_state, stage, attributes, line_number + 1}

        {:comment, comment} ->
          if function_exported?(handler, :line_comment, 2) do
            {coh, uhs} = handler.line_comment(comment, handler_state)
            {coh, uhs, stage, attributes, line_number + 1}
          else
            {:cont, handler_state, stage, attributes, line_number + 1}
          end

        {:relation, name, comment} when stage == :"@relation" ->
          if function_exported?(handler, :relation, 3) do
            {coh, uhs} = handler.relation(name, comment, handler_state)
            {coh, uhs, :"@attribute", attributes, line_number + 1}
          else
            {:cont, handler_state, :"@attribute", attributes, line_number + 1}
          end

        {:attribute, name, :relational, _comment} = attribute
        when stage == :"@attribute" or stage == :"@attribute or @data" ->
          halt_with_error("Attribute type relational is not currently supported.", handler, handler_state, {:halt, attributes, line_number})
          # rough outline for handling relational attributes:
          #   set stage=:"@attribute or @end"
          #   accumulate sub attributes until @end is encountered
          # parsing/casting will need to be adapted, too

        {:attribute, name, _type, _comment} = attribute
        when stage == :"@attribute" or stage == :"@attribute or @data" ->

          # TODO: make this check more clear and efficient; sort out that internal state... header_finished is not needed anymore; maybe use a map
          if Enum.find(attributes, false, fn {:attribute, an, _, _} -> an == name end) do
            halt_with_error(
              "Duplicate attribute name #{name}.",
              handler,
              handler_state,
              {:halt, attributes, line_number}
            )
          else
            {:cont, handler_state, :"@attribute or @data", [attribute | attributes], line_number + 1}
          end

        {:data, comment} when length(attributes) > 0 and stage == :"@attribute or @data" ->
          finished_attributes = Enum.reverse(attributes)

          {cont_or_halt, updated_handler_state} =
            handler.attributes(finished_attributes, handler_state)

          case cont_or_halt do
            :halt ->
              {:halt, updated_handler_state, :halt, finished_attributes, line_number + 1}

            :cont ->
              if function_exported?(handler, :begin_data, 2) do
                {coh, uhs} = handler.begin_data(comment, updated_handler_state)
                {coh, uhs, :instance, finished_attributes, line_number + 1}
              else
                {:cont, updated_handler_state, :instance, finished_attributes, line_number + 1}
              end
          end

        {:raw_instance, _, _, _} = ri when stage == :instance ->
          case cast(ri, attributes, date_parse) do
            {:error, reason} ->
              halt_with_error(reason, handler, handler_state, {:halt, attributes, line_number})

            {:instance, values, weight, comment} ->
              {coh, uhs} = handler.instance(values, weight, comment, handler_state)
              {coh, uhs, :instance, attributes, line_number + 1}
          end

        {:error, reason} ->
          halt_with_error(reason, handler, handler_state, {:halt, attributes, line_number})

        _ ->
          halt_with_error(
            ~s"Expected #{Atom.to_string(stage)}.",
            handler,
            handler_state,
            {:halt, attributes, line_number}
          )
      end

      {cont_or_halt, {handler, updated_handler_state, updated_stage, updated_attributes, date_parse, updated_line_number} }
  end

  # TODO: flatten internal state argument...
  defp halt_with_error(reason, _handler, handler_state, {stage, attributes, line_number}) do
    {:halt, {:error, reason, handler_state}, stage, attributes, line_number}
  end

  @doc false
  def cast({:raw_instance, raw_values, weight, comment}, attributes, date_parse) do
    case cv(raw_values, attributes, [], date_parse) do
      {:error, _reason} = err -> err
      cast_values -> {:instance, cast_values, weight, comment}
    end
  end

  defp cv([], [], acc, _), do: Enum.reverse(acc)

  defp cv([v | vs], [a | as], acc, date_parse) do
    case c(v, a, date_parse) do
      {:error, _reason} = err ->
        err

      cast_value ->
        cv(vs, as, [cast_value | acc], date_parse)
    end
  end

  defp cv([_v | _vs], [], _, _), do: {:error, "More values than attributes."}
  defp cv([], [_a | _as], _, _), do: {:error, "Fewer values than attributes."}

  defp c({:unclosed_quote, quoted}, {:attribute, name, _, _}, _),
    do: {:error, ~s"#{quoted} is missing closing quote for attribute #{name}."}

  defp c(:missing, _, _), do: :missing

  defp c("." <> v, {:attribute, _, :numeric, _} = att, date_parse),
       do: c("0." <> v, att, date_parse)

  defp c("-." <> v, {:attribute, _, :numeric, _} = att, date_parse),
       do: c("-0." <> v, att, date_parse)

  defp c(v, {:attribute, name, :numeric, _}, _) do
    case Integer.parse(v) do
      {i, ""} ->
        i

      _ ->
        case Float.parse(v) do
          {f, ""} ->
            f

          {_f, remainder} ->
            {:error,
             ~s"Nonempty remainder #{remainder} when parsing #{v} as integer/real for attribute #{
               name
             }."}

          :error ->
            {:error, ~s"Cannot cast #{v} to integer/real for attribute #{name}."}
        end
    end
  end

  # could use a set here instead of a list....
  defp c(v, {:attribute, name, {:nominal, enum}, _}, _) do
    if v in enum do
      String.to_atom(v)
    else
      {:error, ~s"Unexpected nominal value #{v} for attribute #{name}."}
    end
  end

  defp c(v, {:attribute, _, :string, _}, _), do: v

  defp c(v, {:attribute, name, {:date, :iso_8601}, _}, _) do
    case DateTime.from_iso8601(v) do
      {:ok, dt, _} ->
        dt

      {:error, :invalid_format} ->
        {:error, ~s"Cannot parse #{v} as ISO-8601 date for attribute #{name}."}
    end
  end

  defp c(v, {:attribute, name, {:date, custom_format}, _}, date_parse) do
    #TODO: call date_parse
    {:error, "Attribute #{name}: date format #{custom_format} not supported; please pass a custom date parsing function."}
  end

  @doc false
  def custom_date_parse(d, format) do
    {:error, "Please pass in a function for parsing non-iso_8601 dates."}
  end

  @doc false
  def parse([:line_break]), do: :empty_line

  def parse([:open_curly | _rest]), do: {:error, "Sparse format is not currently supported."}

  def parse([{:comment, _comment} = comment]), do: comment

  def parse([{:string, <<c::utf8, _::binary>> = s} | rest]) when c == ?@ do
    case String.downcase(s) do
      "@relation" ->
        parse_relation(rest)

      "@attribute" ->
        parse_attribute(rest)

      "@end" ->
        parse_end(rest)

      "@data" ->
        # TODO: this is going to be repeated x times! Is there some nicer, less repetitive way of expressing this?
        case parse_optional_comment(rest) do
          {:error, _reason} = err -> err
          comment -> {:data, comment}
        end
    end
  end

  def parse(instance), do: parse_raw_instance(instance)

  defp parse_relation([{:unclosed_quote, _quoted}]),
    do: {:error, "Unclosed quote in @relation."}

  defp parse_relation([{:string, name} | rest]) do
    case parse_optional_comment(rest) do
      {:error, _reason} = err ->
        err

      comment ->
        {:relation, name, comment}
    end
  end

  defp parse_attribute([{:unclosed_quote, _quoted}]),
    do: {:error, "Unclosed quote in @attribute."}

  defp parse_attribute([{:string, name}, {:string, type} | rest]) do
    case String.downcase(type) do
      n when n in ["integer", "real", "numeric"] ->
        # TODO: try to get rid of the repeated case {:error, reason} blocks
        case parse_optional_comment(rest) do
          {:error, _reason} = err -> err
          comment -> {:attribute, name, :numeric, comment}
        end

      "string" ->
        case parse_optional_comment(rest) do
          {:error, _reason} = err -> err
          comment -> {:attribute, name, :string, comment}
        end

      "date" ->
        parse_date(rest, name)

      "relational" ->
        case parse_optional_comment(rest) do
          {:error, _reason} = err -> err
          comment -> {:attribute, name, :relational, comment}
        end
        # this needs to be reflected in the main loop's state, i.e. accumulated sub-attributes & await 'end'
    end
  end

  defp parse_attribute([{:string, name}, :open_curly | rest]) do
    case pn(rest, []) do
      {:error, _reason} = err -> err
      {enum, comment} -> {:attribute, name, {:nominal, enum}, comment}
    end
  end

  defp parse_attribute([{:string, _name} = n, :tab | rest]), do: parse_attribute([n | rest])

  defp pn([:close_curly | rest], acc) do
    case parse_optional_comment(rest) do
      {:error, _reason} = err -> err
      comment -> {Enum.reverse(acc), comment}
    end
  end

  defp pn([{:string, const}, :comma | rest], acc), do: pn(rest, [const | acc])

  defp pn([{:string, const}, :close_curly | rest], acc) do
    case parse_optional_comment(rest) do
      {:error, _reason} = err -> err
      comment -> {Enum.reverse([const | acc]), comment}
    end
  end

  defp parse_date([{:string, format} | rest], name) do
    # TODO: find way to reduce this duplication
    case parse_optional_comment(rest) do
      {:error, _reason} = err -> err
      comment -> 
        {:attribute, name, {:date, format}, comment}
    end
  end

  defp parse_date(rest, name) do
    # TODO: find way to reduce this duplication
    case parse_optional_comment(rest) do
      {:error, _reason} = err -> err
      comment -> {:attribute, name, {:date, :iso_8601}, comment}
    end
  end

  defp parse_end([{:string, name} | rest]) do
    case parse_optional_comment(rest) do
      {:error, _reason} = err -> err
      comment -> {:end, name, comment}
    end
  end

  defp parse_optional_comment([:tab | rest]), do: parse_optional_comment(rest)
  defp parse_optional_comment([:line_break]), do: nil
  defp parse_optional_comment([{:comment, comment}]), do: comment
  defp parse_optional_comment(unexpected), do: {:error, ~s"Unexpected: #{inspect(unexpected)}"}

  defp parse_raw_instance(rest), do: pri(rest, [])

  defp pri([val, sep, :open_curly, {:string, weight}, :close_curly | rest], acc)
       when sep == :tab or sep == :comma do
    case parse_optional_comment(rest) do
      {:error, _reason} = err ->
        err

      comment ->
        {:raw_instance, Enum.reverse([value(val) | acc]), Integer.parse(weight) |> elem(0),
         comment}
    end
  end

  defp pri([:comma | rest], acc),
    do: pri(rest, [:missing | acc])

  defp pri([val, sep | rest], acc) when sep == :tab or sep == :comma,
    do: pri(rest, [value(val) | acc])

  defp pri([{:comment, _} | _rest] = cr, acc) do
    case parse_optional_comment(cr) do
      {:error, _reason} = err -> err
      comment -> {:raw_instance, Enum.reverse(acc), 1, comment}
    end
  end

  defp pri([:tab | rest], acc),
    do: pri(rest, acc)

  defp pri([{:unclosed_quote, _quoted} = uq], acc),
    do: {:raw_instance, Enum.reverse([uq | acc]), 1, nil}

  defp pri([val | rest], acc) do
    case parse_optional_comment(rest) do
      {:error, _reason} = err -> err
      comment -> {:raw_instance, Enum.reverse([value(val) | acc]), 1, comment}
    end
  end

  defp value({:string, v}), do: v
  defp value(:missing), do: :missing

  @doc false
  def tokenize(line) do
    line
    |> t([])
    |> Enum.reverse()
  end

  defp t(<<>>, acc), do: [:line_break | acc]
  defp t(<<c::utf8, _rest::binary>> = comment, acc) when c == ?%, do: [{:comment, comment} | acc]
  defp t(<<c::utf8, rest::binary>>, acc) when c == 32, do: t(rest, acc)
  defp t(<<c::utf8>>, acc) when c == ?\n, do: [:line_break | acc]
  defp t(<<c::utf8, rest::binary>>, acc) when c == ?\t, do: t(rest, [:tab | acc])
  defp t(<<c::utf8, rest::binary>>, acc) when c == ?,, do: t(rest, [:comma | acc])
  defp t(<<c::utf8, rest::binary>>, acc) when c == ?{, do: t(rest, [:open_curly | acc])
  defp t(<<c::utf8, rest::binary>>, acc) when c == ?}, do: t(rest, [:close_curly | acc])
  defp t(<<c::utf8, rest::binary>>, acc) when c == ??, do: t(rest, [:missing | acc])

  defp t(<<c::utf8, rest::binary>> = quoted, acc) when c == ?' or c == ?" do
    case q(rest, c, <<>>) do
      :unclosed_quote ->
        [{:unclosed_quote, quoted} | acc]

      {string, remainder} ->
        t(remainder, [{:string, string} | acc])
    end
  end

  defp t(bin, acc) do
    case :binary.match(bin, [" ", "\t", ",", "\r", "\n", "}"]) do
      {pos, _length} ->
        {string, rest} = String.split_at(bin, pos)
        t(rest, [{:string, string} | acc])

      :nomatch ->
        [:line_break, {:string, bin} | acc]
    end
  end

  defp q(<<bs::utf8, q::utf8, rest::binary>>, qc, acc) when bs == 92 and q == qc,
    do: q(rest, qc, <<acc::binary, q>>)

  defp q(<<q::utf8, rest::binary>>, qc, acc) when q == qc, do: {acc, rest}
  defp q(<<c::utf8, rest::binary>>, qc, acc), do: q(rest, qc, <<acc::binary, c>>)
  defp q(<<>>, _, _), do: :unclosed_quote
end
