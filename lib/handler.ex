defmodule Arfficionado.Handler do
  @moduledoc """
  Handler behaviour. Implement as per your application's requirements (for example, including side effects such as creating and writing to an ETS table).
  """
  # TODO: provide a date-parsing function so we don't need to pull in any libaries...
  # The handler callback `Arfficionado.Handler:close/1` is called in both cases.

  @typedoc """
  Arfficionado.Handler type.
  """
  @type t :: Arfficionado.Handler.t()

  @typedoc """
  Your handler's state.
  """
  @type state() :: any

  @typedoc """
  Return value for most handler callbacks.
  """
  @type updated_state() :: {:cont, state()} | {:halt, state()}

  @typedoc """
  A comment or nil.
  """
  @type optional_comment :: comment() | nil

  @typedoc """
  A comment.
  """
  @type comment :: String.t()

  @typedoc """
  An instance's attribute-values.
  """
  @type values() :: list(value())

  @typedoc """
  An attribute-value. 
  """
  @type value() :: number() | String.t() | atom() | DateTime.t()

  @typedoc """
  Instance weight.
  """
  @type weight() :: integer()

  @typedoc """
  List of attribute definitions (ARFF header).
  """
  @type attributes() :: list(attribute())

  @typedoc """
  An attribute definition with name, type and optional comment.
  """
  @type attribute() :: {:attribute, name(), attribute_type(), optional_comment()}

  @typedoc """
  Attribute type.
  """
  @type attribute_type() :: :integer | :real | :numeric | {:nominal, list(atom())} | :string | {:date, date_format()}

  @typedoc """
  Date format.
  """
  @type date_format() :: :iso_8601 | String.t()

  @typedoc """
  Name for an attribute/relation.
  """
  @type name :: String.t()

  @doc """
  Creates initial state from given argument.
  """
  @callback init(any()) :: state()

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
