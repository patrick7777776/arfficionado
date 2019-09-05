defmodule Arfficionado.Handler do
  @moduledoc """
  Handler behaviour. Implement as per your application's requirements (for example, including side effects such as creating and writing to an ETS table).
  """
  # provide a date-parsing function so we don't need to pull in any libaries...

  @type t :: Arfficionado.Handler.t()

  @type state() :: any
  @type updated_state() :: {:cont, state()} | {:halt, state()}
  @type optional_comment :: String.t() | nil
  @type comment :: String.t()
  @type values() :: list(any)
  @type weight() :: integer()
  @type attributes() :: list(any)
  @type name :: String.t()

  @doc """
  Invoked when a line is encountered that contains nothing but a comment.
  """
  @callback line_comment(comment(), state()) :: updated_state()
  @optional_callbacks line_comment: 2

  @doc """
  Invoked when @relation is encountered, reporting the relation name and an optional comment.
  """
  @callback relation(name(), optional_comment(), state()) :: updated_state()
  @optional_callbacks relation: 3

  @doc """
  Invoked once all @attributes have been parsed.
  """
  @callback attributes(attributes(), state()) :: updated_state()

  @doc """
  Invoked when @data has been encountered, reporting the optional comment following @data.
  """
  @callback begin_data(optional_comment(), state()) :: updated_state()
  @optional_callbacks begin_data: 2

  @doc """
  Invoked for each data instance, reporting the list of attribute-values (in the order given in the ARFF header), the instance weight (defaulting to 1) and an optional comment.

  Return `{:cont, updated_state}` to continue parsing, or `{:halt, updated_state}` to stop early.
  """
  @callback instance(values(), weight(), optional_comment(), state()) :: updated_state()

  # TODO: pass success | failure to the close call
  @doc """
  Invoked when the input has been exhausted or an error has been encountered.
  """
  @callback close(state()) :: state()
end
