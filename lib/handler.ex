  # TODO: provide a date-parsing function so we don't need to pull in any libaries...
defmodule Arfficionado.Handler do
  @moduledoc """
  Handler behaviour. 
  
  `Arfficionado.read/3` will: 
  1. call `init(arg)` to obtain the initial handler state (`arg` defaults to `nil`)
  2. parse the ARFF header and
     - call `relation` with the relation name and optional comment
     - call `attributes` with the list of attributes found in the header
     - call `line_comment` for lines that consists of commentary only
     - call `begin_data` with optional comment to indicate that the header is finished and instance data will follow
  3. parse the ARFF data section
    - call `instance` for each line of data, reporting instance values, weight and optional comment
    - call `line_comment` for lines that consists of commentary only
  4. call `close`
  
  `Arfficionado.read/3` will pass in the current handler state on each callback invocation. Callback functions return an updated handler state and generally indicate whether to continue reading the ARFF file or to stop early.

  Once the ARFF file is exhausted, an error is encountered in the ARFF file, or the handler has indicated that it wishes to stop the processing, the `close` callback will be invoked, allowing the handler to create the final result state (and clean up resources).
  
  Implement this behaviour as per your application's requirements (for example, including side effects such as creating and writing to an ETS table). The sources for `Arfficionado.ListHandler` and `Arfficionado.MapHandler` may provide some general guidance. 
  """

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
  @type attribute_type() :: :numeric | {:nominal, list(atom())} | :string | {:date, date_format()}

  @typedoc """
  Date format.
  """
  @type date_format() :: :iso_8601 | String.t()

  @typedoc """
  Name for an attribute/relation.
  """
  @type name :: String.t()

  @typedoc """
  Success/failure indicator.
  """
  @type status() :: :ok | :error

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
  Invoked when the processing has finished. The first argument indicates whether processing was successful (`:ok`) or an error was encountered (`:error`).
  """
  @callback close(status(), state()) :: state()
end
