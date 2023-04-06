# FunServer

[![hex.pm version](https://img.shields.io/hexpm/v/fun_server.svg?style=flat)](https://hex.pm/packages/fun_server)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg?style=flat)](https://hexdocs.pm/fun_server/)
[![Total Download](https://img.shields.io/hexpm/dt/fun_server.svg?style=flat)](https://hex.pm/packages/fun_server)
[![License](https://img.shields.io/hexpm/l/fun_server.svg?style=flat)](https://github.com/gspasov/fun_server/blob/main/LICENSE)

FunServer is a way of writing `GenServer` using functions instead of callbacks.

Writing `GenServer` usually ends up with having an "API" section and "callbacks" section, making you go back and forth between these two sections when adding new functionality. `FunServer` allows you to write both in the same place. This make you stop worrying about where to place your callback and just go about your functionality.

Simple and straight to the point.

`FunServer` allows you to pass functions for:
  - `init/1`
  - `handle_call/3`
  - `handle_cast/2`
  - `handle_continue/2`

The rest of the `GenServer` callbacks can be handled just as before using callbacks:
  - `handle_info/2`
  - `terminate/2`
  - `format_status/2`
  - `code_change/3`


## Usage

```elixir
defmodule Server do
  use FunServer

  require Logger

  def start_link(_args) do
    FunServer.start_link(__MODULE__, fn -> {:ok, []} end, name: __MODULE__)
  end

  def state() do 
    FunServer.sync(__MODULE__, fn _from, state -> {:reply, state, state} end)
  end

  def push(value) do
    FunServer.async(__MODULE__, fn state ->
      {:noreply, [value | state]}
    end)
  end

  def push_twice(value) do
    FunServer.async(__MODULE__, fn state ->
      {:noreply, [value | state], {:continue, fn state -> {:noreply, [value | state]} end}}
    end)
  end

  def pop(value) do
    FunServer.sync(__MODULE__, fn _from, [value | new_state] ->
      {:noreply, value, new_state}
    end)
  end

  @impl true
  def handle_info(message, state) do
    Logger.warn("Got an unexpected message: #{inspect(message)}")
    {:noreply, state}
  end
end
```

## Installation
Add `:fun_server` as a dependency to your project's mix.exs:

```elixir
defp deps do
  [
    {:fun_server, "~> 0.1.3"}
  ]
end
```

