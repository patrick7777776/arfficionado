defmodule Arfficionado.Handler do
  @moduledoc """
  Handler behaviour. Implement as per your application's requirements (for example, including side effects such as creating and writing to an ETS table).
  """
  # provide a date-parsing function so we don't need to pull in any libaries...

  @type t :: Arfficionado.Handler.t()

  @type state() :: any
  @type updated_state() :: {:cont, state()} | {:halt, state()}
  @type comment :: String.t() | nil
  @type values() :: list(any)
  @type attributes() :: list(any)

  @callback line_comment(String.t(), state()) :: updated_state()
  @callback relation(String.t(), comment(), state()) :: updated_state()
  @callback attributes(attributes(), state()) :: updated_state()
  @callback begin_data(comment(), state()) :: updated_state()
  @callback instance(values(), integer(), comment(), state()) :: updated_state()

  # TODO: pass success | failure to the close call
  @callback close(state()) :: state()
end
