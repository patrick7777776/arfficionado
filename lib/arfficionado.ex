defmodule Arfficionado do
  def read(stream, handler, initial_handler_state) do
    case Enum.reduce_while(stream, {handler, initial_handler_state, {[], false, 1}}, &process_line/2) do
      {_, {:error, reason, handler_state}, {_, _, line_number}} ->
        final_state = handler.close(handler_state)
        {:error, ~s"Line #{line_number}: #{reason}", final_state}
      {_, handler_state, _} ->
        final_state = handler.close(handler_state)
        {:ok, final_state}
    end
  end

  # on parse error return {:error, reason, handler_state}; pass handler state into close; return error
  defp process_line(line, {handler, handler_state, {attributes, header_finished, line_number}}) do
    parsed =
      line
      |> tokenize()
      |> parse()

    {cont_or_halt, updated_handler_state, updated_internal_state} =
      case parsed do
        :empty_line ->
          {:cont, handler_state, {attributes, header_finished, line_number + 1}}

        {:comment, comment} ->
          {coh, uih} = handler.line_comment(comment, handler_state)
          {coh, uih, {attributes, header_finished, line_number + 1}}

        {:relation, name, comment} ->
          {coh, uih} = handler.relation(name, comment, handler_state)
          {coh, uih, {attributes, header_finished, line_number + 1}}

        {:attribute, _name, _type, _comment} = attribute when not header_finished ->
          # TODO: handle relational attributes!!!!
          {:cont, handler_state, {[attribute | attributes], header_finished, line_number + 1}}

        {:data, comment} ->
          finished_attributes = Enum.reverse(attributes)

          {cont_or_halt, updated_handler_state} =
            handler.attributes(finished_attributes, handler_state)

          case cont_or_halt do
            :halt ->
              {:halt, updated_handler_state, {finished_attributes, true, line_number + 1}}

            :cont ->
              {coh, uhs} = handler.begin_data(comment, updated_handler_state)
              {coh, uhs, {finished_attributes, true, line_number + 1}}
          end

        {:raw_instance, _, _, _} = ri when header_finished ->
          case cast(ri, attributes) do
            {:error, reason}  ->
              halt_with_error(reason, handler, handler_state, {attributes, header_finished, line_number })

            {:instance, values, weight, comment} -> 
              {coh, uhs} = handler.instance(values, weight, comment, handler_state)
              {coh, uhs, {attributes, header_finished, line_number + 1}}
          end
      end

    {cont_or_halt, {handler, updated_handler_state, updated_internal_state}}
  end

  defp halt_with_error(reason, handler, handler_state, internal_state) do
    # TODO: add report_error function to handler, call it .. or .. add flag to close
    {:halt, {:error, reason, handler_state}, internal_state}
  end

  def cast({:raw_instance, raw_values, weight, comment}, attributes) do
    case cv(raw_values, attributes, []) do
      {:error, _reason} = err -> err
      cast_values -> {:instance, cast_values, weight, comment}
    end
  end

  defp cv([], [], acc), do: Enum.reverse(acc)
  defp cv([v | vs], [a | as], acc), do: cv(vs, as, [c(v, a) | acc])
  defp cv([v | vs], [], _), do: {:error, "More values than attributes."}
  defp cv([], [a | as], _), do: {:error, "Fewer values than attributes."}

  defp c(:missing, _), do: :missing

  defp c(v, {:attribute, _, :integer, _}) do
    case Integer.parse(v) do
      {i, ""} -> i
      _ ->
        # be lenient -- some files have float values in an int column
        {f, ""} = Float.parse(v)
        f
    end
  end

  defp c("." <> v, {:attribute, _, type, _} = att) when type == :real or type == :numeric, do: c("0." <> v, att)
  defp c("-." <> v, {:attribute, _, type, _} = att) when type == :real or type == :numeric, do: c("-0." <> v, att)

  defp c(v, {:attribute, _, :real, _}) do
    case Float.parse(v) do
      {f, ""} -> f
    end
  end

  defp c(v, {:attribute, _, :numeric, _}) do
    case Integer.parse(v) do
      {i, ""} ->
        i

      _ ->
        {f, ""} = Float.parse(v)
        f
    end
  end

  # could use a set here instead of a list....
  defp c(v, {:attribute, name, {:nominal, enum}, _}) do
    if v in enum do
      String.to_atom(v)
    else
      raise ArgumentError, ~s"attribute #{name} unexpected nominal value: #{v}"
    end
  end

  defp c(v, {:attribute, _, :string, _}), do: v

  defp c(v, {:attribute, _, {:date, :iso_8601}, _}) do
    {:ok, dt, _} = DateTime.from_iso8601(v)
    dt
  end

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
