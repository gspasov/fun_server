# FunServer

FunServer is a way of writing `GenServer` using functions instead of callbacks.

## Installation
Add `:fun_server` as a dependency to your project's mix.exs:

```elixir
defp deps do
  [
    {:fun_server, "~> 0.1.0"}
  ]
end
```

## Usage

```elixir
defmodule Server do
  use FunServer

  def start_link(_args) do
    FunServer.start_link(__MODULE__, fn -> {:ok, []} end, name: __MODULE__)
  end

  def state() do 
    FunServer.sync(fn _from, state -> {:reply, state, state} end, __MODULE__)
  end

  def push(value) do
    value
    |> handle_push()
    |> FunServer.async(__MODULE__)
  end

  def pop(value) do
    value
    |> handle_pop()
    |> FunServer.sync(__MODULE__)
  end

  defp handle_push(value) do
    fn state ->
      {:noreply, [value | state]}
    end
  end

  defp handle_pop(value) do
    fn _from, [value | new_state] ->
      {:noreply, value, new_state}
    end
  end
end
```
