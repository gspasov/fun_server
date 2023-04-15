defmodule FunServerTest do
  use ExUnit.Case
  doctest FunServer

  setup_all do
    defmodule TestServer do
      use FunServer

      defmodule Inner do
        def push_sync(elem) do
          fn _from, state ->
            new_state = [elem | state]
            {:reply, new_state, new_state}
          end
        end

        def push_async(elem) do
          fn state -> {:noreply, [elem | state]} end
        end
      end

      def start_link(initial_state) do
        FunServer.start_link(__MODULE__, [name: __MODULE__], fn -> {:ok, initial_state} end)
      end

      def push(server, elem) do
        FunServer.async(server, fn state -> {:noreply, [elem | state]} end)
      end

      def push_mfa_sync(server, elem) do
        FunServer.sync(server, {Inner, :push_sync, [elem]})
      end

      def push_mfa_async(server, elem) do
        FunServer.async(server, {Inner, :push_async, [elem]})
      end

      def push_twice(server, elem) do
        FunServer.async(server, fn state ->
          {:noreply, [elem | state], {:continue, fn state -> {:noreply, [elem | state]} end}}
        end)
      end

      def push_twice_sync(server, elem) do
        FunServer.sync(server, fn _from, state ->
          {:reply, elem, [elem | state], {:continue, fn state -> {:noreply, [elem | state]} end}}
        end)
      end

      def pop(server) do
        FunServer.sync(server, fn
          _from, [elem | new_state] -> {:reply, elem, new_state}
          _from, [] -> {:reply, :empty, []}
        end)
      end

      def slow_pop_timeout(server) do
        FunServer.sync(server, fn
          _from, [elem | new_state] ->
            :timer.sleep(6_000)
            {:reply, elem, new_state}

          _from, [] ->
            :timer.sleep(6_000)
            {:reply, :empty, []}
        end)
      end

      def slow_pop_succeeds(server, timeout) do
        FunServer.sync(server, timeout, fn
          _from, [elem | new_state] ->
            :timer.sleep(6_000)
            {:reply, elem, new_state}

          _from, [] ->
            :timer.sleep(6_000)
            {:reply, :empty, []}
        end)
      end
    end

    [module: TestServer]
  end

  setup %{module: module} do
    {:ok, server} = apply(module, :start_link, [[]])
    [server: server, module: module]
  end

  test "can push one element and pop it out", %{module: module, server: server} do
    :ok = apply(module, :push, [server, 1])
    result = apply(module, :pop, [server])

    assert result == 1
  end

  test "can pop until state is empty", %{module: module, server: server} do
    :ok = apply(module, :push, [server, 1])
    result = apply(module, :pop, [server])
    assert result == 1

    result2 = apply(module, :pop, [server])
    assert result2 == :empty
  end

  test "can call :continue from `FunServer.async/2`", %{module: module, server: server} do
    :ok = apply(module, :push_twice, [server, 1])
    result = apply(module, :pop, [server])
    assert result == 1

    result1 = apply(module, :pop, [server])
    assert result1 == 1

    result2 = apply(module, :pop, [server])
    assert result2 == :empty
  end

  test "can call :continue from `FunServer.sync/3`", %{module: module, server: server} do
    result = apply(module, :push_twice_sync, [server, 1])
    assert result == 1

    result1 = apply(module, :pop, [server])
    assert result1 == 1

    result2 = apply(module, :pop, [server])
    assert result2 == 1

    result3 = apply(module, :pop, [server])
    assert result3 == :empty
  end

  test "can call `FunServer.sync/3` using mfa approach", %{module: module, server: server} do
    result = apply(module, :push_mfa_sync, [server, 1])
    assert result == [1]
  end

  test "slow sync call will timeout after 5_000", %{module: module, server: server} do
    assert match?(
             {:timeout, {GenServer, :call, _}},
             catch_exit(apply(module, :slow_pop_timeout, [server]))
           ),
           "expected call to match on :timeout exit from GenServer"
  end

  test "slow sync call succeed by passing additional timeout value", %{
    module: module,
    server: server
  } do
    result = apply(module, :slow_pop_succeeds, [server, 10_000])
    assert result == :empty
  end

  test "can call `FunServer.async/2` using mfa approach", %{module: module, server: server} do
    :ok = apply(module, :push_mfa_async, [server, 1])
    result = apply(module, :pop, [server])
    assert result == 1
  end
end
