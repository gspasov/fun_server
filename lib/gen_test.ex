defmodule GenTest do
  use FunServer

  def start_link(_args) do
    FunServer.start_link(__MODULE__, handle_init(%{}), name: __MODULE__)
  end

  # ===================#
  # --- Client side ---#
  # ===================#

  def put(key, value) do
    key
    |> handle_put(value)
    |> FunServer.async(__MODULE__)
  end

  def update(key, new_value) do
    key
    |> handle_update(new_value)
    |> FunServer.async(__MODULE__)
  end

  def fetch(key) do
    key
    |> handle_fetch()
    |> FunServer.sync(__MODULE__)
  end

  def delete(key) do
    key
    |> handle_delete()
    |> FunServer.async(__MODULE__)
  end

  # ===================#
  # --- Server side ---#
  # ===================#

  @impl true
  def handle_info(:clear, _state) do
    {:noreply, %{}}
  end

  @impl true
  def handle_info(message, state) do
    IO.inspect(message, label: "handle_info got unknown message")
    {:noreply, state}
  end

  # =========================#
  # --- Private functions ---#
  # =========================#

  defp handle_init(args) do
    fn -> {:ok, args} end
  end

  defp handle_put(key, value) do
    fn state ->
      {:noreply, Map.put(state, key, value)}
    end
  end

  defp handle_update(key, value) do
    fn state ->
      {:noreply, Map.update(state, key, value, fn _old_value -> value end),
       {:continue, &log_state/1}}
    end
  end

  defp handle_fetch(:all) do
    fn
      _from, state when state == %{} ->
        {:reply, :empty, state}

      _from, state ->
        {:reply, state, state}
    end
  end

  defp handle_fetch(key) do
    fn _from, state ->
      {:reply, Map.get(state, key), state}
    end
  end

  defp handle_delete(key) do
    fn state ->
      {:noreply, Map.delete(state, key)}
    end
  end

  defp log_state(state) do
    IO.inspect(state)
    {:noreply, state}
  end
end
