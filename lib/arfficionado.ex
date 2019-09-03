defmodule Arfficionado do

  # make sure that each parse path has an error-catch-all (via tests)
  # do we need to wrap a try catch around this at the top level to ensure that no unexpected error is actually raised?!

  @moduledoc """
    Reader for ARFF (Attribute Relation File Format) files.
    TODO: link to arff
    TODO: general usage idea
    TODO: current limitations
    TODO: use an official arff example file for illustrations...
  """

  @doc """
    Reads a line `stream` that represents an ARFF file and invokes corresponding `handler` callbacks.
    Maintains handler state, which is initialized to `initial_handler_state` and is modified by the callback invocations.

   Returns `{:ok, final_handler_state}` if the stream was processed successfully, and `{:error, reason, final_handler_state}` otherwise. The handler callback `c:close/1` is called in both cases. 


    ## Examples

        iex> File.stream!("my.arff")
        ...> |> Arfficionado.read(Arfficionado.ListHandler, [])
        {:ok, [{[v1_1, v1_2, v1_3], 1}, ... {[vn_1, vn_2, vn_3], 1}]}

  """
  def read(stream, handler, initial_handler_state) do
    case Enum.reduce_while(stream, {handler, initial_handler_state, {:"@relation", [], false, 1}}, &process_line/2) do
      {_, {:error, reason, handler_state}, {_, _, _, line_number}} ->
        final_state = handler.close(handler_state)
        {:error, ~s"Line #{line_number}: #{reason}", final_state}
      {_, handler_state, {stage, _, _, line_number}} when stage != :instance ->
        final_state = handler.close(handler_state)
        {:error, ~s"Line #{line_number}: Expected #{Atom.to_string(stage)}.", final_state} # error msg assembly somewhat duplicated
      {_, handler_state, _} ->
        final_state = handler.close(handler_state)
        {:ok, final_state}
    end
  end

  # TODO: clean up that internal state and its handling; add a state-machine that detects deviations from arff spec (missing header, duplicates, wrong order, ...)
  # TODO: remove header_finished 
  defp process_line(line, {handler, handler_state, {stage, attributes, header_finished, line_number}}) do
    parsed =
      line
      |> tokenize()
      |> parse()

    {cont_or_halt, updated_handler_state, updated_internal_state} =
      case parsed do
        :empty_line ->
          {:cont, handler_state, {stage, attributes, header_finished, line_number + 1}}

        {:comment, comment} ->
          {coh, uih} = handler.line_comment(comment, handler_state)
          {coh, uih, {stage, attributes, header_finished, line_number + 1}}

        {:relation, name, comment} when stage == :"@relation" ->
          {coh, uih} = handler.relation(name, comment, handler_state)
          {coh, uih, {:"@attribute", attributes, header_finished, line_number + 1}}

        {:attribute, _name, _type, _comment} = attribute when stage == :"@attribute" or stage == :"@attribute or @data" ->
          # TODO: handle relational attributes!!!!
          {:cont, handler_state, {:"@attribute or @data", [attribute | attributes], header_finished, line_number + 1}}

        {:data, comment} when length(attributes) > 0 and stage == :"@attribute or @data" ->
          finished_attributes = Enum.reverse(attributes)

          {cont_or_halt, updated_handler_state} =
            handler.attributes(finished_attributes, handler_state)

          case cont_or_halt do
            :halt ->
              {:halt, updated_handler_state, {:halt, finished_attributes, true, line_number + 1}}

            :cont ->
              {coh, uhs} = handler.begin_data(comment, updated_handler_state)
              {coh, uhs, {:instance, finished_attributes, true, line_number + 1}}
          end

        {:raw_instance, _, _, _} = ri when stage == :instance ->
          case cast(ri, attributes) do
            {:error, reason}  ->
              halt_with_error(reason, handler, handler_state, {:halt, attributes, header_finished, line_number })

            {:instance, values, weight, comment} -> 
              {coh, uhs} = handler.instance(values, weight, comment, handler_state)
              {coh, uhs, {:instance, attributes, header_finished, line_number + 1}}
          end

        _ ->
          halt_with_error(~s"Expected #{Atom.to_string(stage)}.", handler, handler_state, {:halt, attributes, header_finished, line_number })

      end

    {cont_or_halt, {handler, updated_handler_state, updated_internal_state}}
  end

  defp halt_with_error(reason, handler, handler_state, internal_state) do
    # TODO: add report_error function to handler, call it .. or .. add flag to close
    {:halt, {:error, reason, handler_state}, internal_state}
  end

  @doc false
  def cast({:raw_instance, raw_values, weight, comment}, attributes) do
    case cv(raw_values, attributes, []) do
      {:error, _reason} = err -> err
      cast_values -> {:instance, cast_values, weight, comment}
    end
  end

  defp cv([], [], acc), do: Enum.reverse(acc)
  defp cv([v | vs], [a | as], acc) do
    case c(v, a) do
      {:error, _reason} = err -> 
        err
      cast_value -> 
        cv(vs, as, [cast_value | acc])
    end
  end
  defp cv([v | vs], [], _), do: {:error, "More values than attributes."}
  defp cv([], [a | as], _), do: {:error, "Fewer values than attributes."}

  defp c(:missing, _), do: :missing

  # integer, float, numeric are all the same to ARFF, so simplify all of this code! Consider making integer/real into numeric and having one numeric case that adds missing -0 / 0 and first tries int then float...
  defp c(v, {:attribute, name, :integer, _}) do
    case Integer.parse(v) do
      {i, ""} -> i
      _ ->
        # be lenient -- some files have float values in an int column
        case Float.parse(v) do
          {f, ""} -> f
          :error -> {:error, ~s"Cannot cast #{v} to integer/real for attribute #{name}."}
        end
    end
  end

  defp c("." <> v, {:attribute, _, type, _} = att) when type == :real or type == :numeric, do: c("0." <> v, att)
  defp c("-." <> v, {:attribute, _, type, _} = att) when type == :real or type == :numeric, do: c("-0." <> v, att)

  defp c(v, {:attribute, name, :real, _}) do
    case Float.parse(v) do
      {f, ""} -> f
      :error -> {:error, ~s"Cannot cast #{v} to integer/real for attribute #{name}."}
    end
  end

  #TODO: duplication with integer case
  defp c(v, {:attribute, name, :numeric, _}) do
    case Integer.parse(v) do
      {i, ""} ->
        i

      _ ->
        case Float.parse(v) do
          {f, ""} -> f
          :error -> {:error, ~s"Cannot cast #{v} to integer/real for attribute #{name}."}
        end
    end
  end

  # could use a set here instead of a list....
  defp c(v, {:attribute, name, {:nominal, enum}, _}) do
    if v in enum do
      String.to_atom(v)
    else
      {:error, ~s"Unexpected nominal value #{v} for attribute #{name}."}
    end
  end

  defp c(v, {:attribute, _, :string, _}), do: v

  defp c(v, {:attribute, name, {:date, :iso_8601}, _}) do
    case DateTime.from_iso8601(v) do
      {:ok, dt, _} -> dt
      {:error, :invalid_format} -> {:error, ~s"Cannot parse #{v} as ISO-8601 date for attribute #{name}."}
    end
  end

  @doc false
  def parse([:line_break]), do: :empty_line

  def parse([{:comment, comment} = cmt]), do: cmt

  def parse([{:string, <<c::utf8, _::binary>> = s} | rest]) when c == ?@ do
    case String.downcase(s) do
      "@relation" -> parse_relation(rest)
      "@attribute" -> parse_attribute(rest)
      "@end" -> parse_end(rest)
      "@data" -> {:data, parse_optional_comment(rest)}
    end
  end

  def parse(instance), do: parse_raw_instance(instance)

  defp parse_relation([{:string, name} | rest]),
    do: {:relation, name, parse_optional_comment(rest)}

  defp parse_attribute([{:string, name}, {:string, type} | rest]) do
    case String.downcase(type) do
      "numeric" -> {:attribute, name, :numeric, parse_optional_comment(rest)}
      "real" -> {:attribute, name, :real, parse_optional_comment(rest)}
      "integer" -> {:attribute, name, :integer, parse_optional_comment(rest)}
      "string" -> {:attribute, name, :string, parse_optional_comment(rest)}
      "date" -> parse_date(rest, name)
      "relational" -> {:attribute, name, :relational, parse_optional_comment(rest)}
    end
  end

  defp parse_attribute([{:string, name}, :open_curly | rest]) do
    {enum, comment} = pn(rest, [])
    {:attribute, name, {:nominal, enum}, comment}
  end

  defp parse_attribute([{:string, name} = n, :tab | rest]), do:
    parse_attribute([n | rest])

  defp pn([:close_curly | rest], acc), do: {Enum.reverse(acc), parse_optional_comment(rest)}
  defp pn([{:string, const}, :comma | rest], acc), do: pn(rest, [const | acc])

  defp pn([{:string, const}, :close_curly | rest], acc),
    do: {Enum.reverse([const | acc]), parse_optional_comment(rest)}

  defp parse_date([{:string, format} | rest], name),
    do: {:attribute, name, {:date, format}, parse_optional_comment(rest)}

  defp parse_date(rest, name),
    do: {:attribute, name, {:date, :iso_8601}, parse_optional_comment(rest)}

  defp parse_end([{:string, name} | rest]), do: {:end, name, parse_optional_comment(rest)}

  defp parse_optional_comment([:tab | rest]), do: parse_optional_comment(rest)
  defp parse_optional_comment([:line_break]), do: nil
  defp parse_optional_comment([{:comment, comment}]), do: comment

  defp parse_raw_instance(rest), do: pri(rest, [])

  defp pri([val, sep, :open_curly, {:string, weight}, :close_curly | rest], acc)
       when sep == :tab or sep == :comma,
       do:
         {:raw_instance, Enum.reverse([value(val) | acc]), Integer.parse(weight) |> elem(0),
          parse_optional_comment(rest)}

  defp pri([val, sep | rest], acc) when sep == :tab or sep == :comma,
    do: pri(rest, [value(val) | acc])

  defp pri([val | rest], acc),
    do: {:raw_instance, Enum.reverse([value(val) | acc]), 1, parse_optional_comment(rest)}

  defp value({:string, v}), do: v
  defp value(:missing), do: :missing

  @doc false
  def tokenize(line) do
    line
    |> t([])
    |> Enum.reverse()
  end

  defp t(<<>>, acc), do: acc
  defp t(<<c::utf8, rest::binary>> = comment, acc) when c == ?%, do: [{:comment, comment} | acc]
  defp t(<<c::utf8, rest::binary>>, acc) when c == 32, do: t(rest, acc)
  defp t(<<c::utf8>>, acc) when c == ?\n, do: [:line_break | acc]
  defp t(<<c::utf8, rest::binary>>, acc) when c == ?\t, do: t(rest, [:tab | acc])
  defp t(<<c::utf8, rest::binary>>, acc) when c == ?,, do: t(rest, [:comma | acc])
  defp t(<<c::utf8, rest::binary>>, acc) when c == ?{, do: t(rest, [:open_curly | acc])
  defp t(<<c::utf8, rest::binary>>, acc) when c == ?}, do: t(rest, [:close_curly | acc])
  defp t(<<c::utf8, rest::binary>>, acc) when c == ??, do: t(rest, [:missing | acc])

  defp t(<<c::utf8, rest::binary>>, acc) when c == ?' or c == ?" do
    [string, remainder] = :binary.split(rest, [List.to_string([c])])
    t(remainder, [{:string, string} | acc])
  end

  defp t(bin, acc) do
    case :binary.match(bin, [" ", "\t", ",", "\r", "\n", "}"]) do
      {pos, _length} -> 
        {string, rest} = String.split_at(bin, pos)
        t(rest, [{:string, string} | acc])
      :nomatch -> # occurs if last line in file has no linebreak
        t("\n", [{:string, bin} | acc])
    end
  end
end
