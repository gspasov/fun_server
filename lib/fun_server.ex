defmodule FunServer do
  @moduledoc """
  `FunServer` is a GenServer in which
  instead of passing parameters to `GenServer.call/3` or `GenServer.cast/2`
  and then writing the corresponding callbacks with the necessary functionality
  you pass functions (i.e. `handlers`).

  Essentially `FunServer` is just a simple wrapper over `GenServer`, which takes the approach of
  passing down functions instead of messages.

  ## Example
  Basically instead of using `handle_call` or `handle_cast` callbacks,
  functions are being passed that get executed in the corresponding callback.

  This is an example of a simple `FunServer` Stack Server.

      defmodule Server do
        use FunServer

        def start_link(_args) do
          FunServer.start_link(__MODULE__, handle_init([]), name: __MODULE__)
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

        defp handle_init(args) do
          fn -> {:ok, args} end
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

  The callbacks `FunServer` wraps around are the following:
    - `init/1`
    - `handle_call/3`
    - `handle_cast/2`
    - `handle_continue/2`

  The rest of the callbacks for `GenServer` can be handled normally:
    - `handle_info/2`
    - `terminate/2`
    - `code_change/3`
    - `format_status/2`
  """

  @doc false
  defmacro __using__(opts) do
    quote do
      use GenServer, unquote(opts)

      @impl true
      def init(f), do: f.()

      @impl true
      def handle_continue(f, state), do: f.(state)

      @impl true
      def handle_call(f, from, state), do: f.(from, state)

      @impl true
      def handle_cast(f, state), do: f.(state)
    end
  end

  @doc """
  Starts a `FunServer` process without links (outside of a supervision tree)

  _For more information please refer to `GenServer.start/3`_
  """
  @spec start(module :: atom(), init_handler, options :: GenServer.options()) ::
          {:ok, pid()} | {:error, any()} | :ignore
        when init_handler:
               (() -> {:ok, state :: term()}
                      | {:ok, state :: term(),
                         timeout() | :hibernate | {:continue, continue_handler}}
                      | :ignore
                      | {:stop, reason :: any()}),
             continue_handler:
               (state :: term() ->
                  {:noreply, new_state :: term()}
                  | {:noreply, new_state :: term(),
                     timeout() | :hibernate | {:continue, continue_handler}}
                  | {:stop, reason :: any(), new_state :: term()})
  def start(module, init_handler, options \\ []) do
    GenServer.start(module, init_handler, options)
  end

  @doc """
  Starts a `FunServer` process linked to the current 'caller' process.

  _For more information please refer to `GenServer.start_link/3`_
  """
  @spec start_link(module :: atom(), init_handler, options :: GenServer.options()) ::
          {:ok, pid()} | {:error, any()} | :ignore
        when init_handler:
               (() -> {:ok, state :: term()}
                      | {:ok, state :: term(),
                         timeout() | :hibernate | {:continue, continue_handler}}
                      | :ignore
                      | {:stop, reason :: any()}),
             continue_handler:
               (state :: term() ->
                  {:noreply, new_state :: term()}
                  | {:noreply, new_state :: term(),
                     timeout() | :hibernate | {:continue, continue_handler}}
                  | {:stop, reason :: any(), new_state :: term()})
  def start_link(module, init_handler, options \\ []) do
    GenServer.start_link(module, init_handler, options)
  end

  @doc """
  Synchronously stops the server with the given `reason`.

  _For more information please refer to `GenServer.stop/3`_
  """
  @spec stop(server :: GenServer.server(), reason :: term(), timeout :: timeout()) :: :ok
  def stop(server, reason \\ :normal, timeout \\ :infinity) do
    GenServer.stop(server, reason, timeout)
  end

  @doc """
  Calls all servers locally registered as name at the specified nodes.

  _For more information please refer to `GenServer.multi_call/4`_
  """
  @spec multi_call(
          nodes :: [node()],
          name :: atom(),
          request :: term(),
          timeout :: timeout()
        ) ::
          {replies :: [{node(), term()}], bad_nodes :: [node()]}
  def multi_call(nodes \\ [node() | Node.list()], name, request, timeout \\ :infinity) do
    GenServer.multi_call(nodes, name, request, timeout)
  end

  @doc """
  Casts all servers locally registered as name at the specified nodes.

  _For more information please refer to `GenServer.abcast/3`_
  """
  @spec abcast(nodes :: [node()], name :: atom(), request :: term()) :: :abcast
  def abcast(nodes \\ [node() | Node.list()], name, request) do
    GenServer.abcast(nodes, name, request)
  end

  @doc """
  Replies to a client.

  _For more information please refer to `GenServer.reply/2`_
  """
  @spec reply(from :: GenServer.from(), reply :: term()) :: :ok
  def reply(client, reply) do
    GenServer.reply(client, reply)
  end

  @doc """
  Executes a synchronous call to the `server` and waits for a reply.
  Works very similar to how a `GenServer.call/3` function works, but instead of passing message
  which is later handled in a `handle_call/3` callback, a function is passed, which gets evaluated
  on the `server`.

  _For additional information please refer to `GenServer.call/3`_
  """
  @spec sync(
          handler :: (from :: GenServer.from(), state :: term() -> handler_response),
          server :: GenServer.server(),
          timeout :: timeout()
        ) :: term()
        when handler_response:
               {:reply, reply, new_state}
               | {:reply, reply, new_state,
                  timeout() | :hibernate | {:continue, continue_arg :: term()}}
               | {:noreply, new_state}
               | {:noreply, new_state,
                  timeout() | :hibernate | {:continue, continue_arg :: term()}}
               | {:stop, reason, reply, new_state}
               | {:stop, reason, new_state},
             reply: term(),
             new_state: term(),
             reason: term()
  def sync(handler, server, timeout \\ 5_000) do
    GenServer.call(server, handler, timeout)
  end

  @doc """
  Executes an asynchronous call to the `server`.
  Works very similar to how a `GenServer.cast/2` function works, but instead of passing message
  which is later handled in a `handle_cast/2` callback, a function is passed, which gets evaluated
  on the `server`.

  _For additional information please refer to `GenServer.cast/2`_
  """
  @spec async(
          handler :: (state :: term() -> handler_response),
          server :: GenServer.server()
        ) :: term()
        when handler_response:
               {:noreply, new_state}
               | {:noreply, new_state,
                  timeout() | :hibernate | {:continue, continue_arg :: term()}}
               | {:stop, reason :: term(), new_state},
             new_state: term()
  def async(handler, server) do
    GenServer.cast(server, handler)
  end
end
