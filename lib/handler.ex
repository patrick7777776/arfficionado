defmodule Arfficionado.Handler do
  # provide a date-parsing function so we don't need to pull in any libaries...

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
  @callback close(state()) :: state()
end
