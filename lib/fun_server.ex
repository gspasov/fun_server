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

  @type reply :: term()
  @type state :: term()
  @type new_state :: term()
  @type reason :: any()

  @type init_handler ::
          (() -> {:ok, state()}
                 | {:ok, state(), timeout() | :hibernate | {:continue, async_func_handler()}}
                 | :ignore
                 | {:stop, reason()})

  @type sync_handler_response ::
          {:reply, reply(), new_state()}
          | {:reply, reply(), new_state(),
             timeout() | :hibernate | {:continue, async_func_handler()}}
          | {:noreply, new_state()}
          | {:noreply, new_state(), timeout() | :hibernate | {:continue, async_func_handler()}}
          | {:stop, reason(), reply(), new_state()}
          | {:stop, reason(), new_state()}

  @type sync_func_handler ::
          (from :: GenServer.from(), state() -> sync_handler_response())

  @type async_handler_response ::
          {:noreply, new_state()}
          | {:noreply, new_state(), timeout() | :hibernate | {:continue, async_func_handler()}}
          | {:stop, reason(), new_state()}

  @type async_func_handler :: mfa() | (state() -> async_handler_response())

  @type sync_handler :: mfa() | sync_func_handler()

  @type async_handler :: mfa() | async_func_handler()

  @doc false
  defmacro __using__(opts) do
    quote do
      use GenServer, unquote(opts)

      @impl true
      def init({m, f, a}) when is_atom(m) and is_atom(f) and is_list(a) do
        apply(m, f, a)
      end

      @impl true
      def init(f) when is_function(f) do
        f.()
      end

      @impl true
      def handle_continue({m, f, a}, state) when is_atom(m) and is_atom(f) and is_list(a) do
        apply(m, f, a).(state)
      end

      @impl true
      def handle_continue(f, state) when is_function(f) do
        f.(state)
      end

      @impl true
      def handle_call({m, f, a}, from, state) when is_atom(m) and is_atom(f) and is_list(a) do
        apply(m, f, a).(from, state)
      end

      @impl true
      def handle_call(f, from, state) when is_function(f) do
        f.(from, state)
      end

      @impl true
      def handle_cast({m, f, a}, state) when is_atom(m) and is_atom(f) and is_list(a) do
        apply(m, f, a).(state)
      end

      @impl true
      def handle_cast(f, state) when is_function(f) do
        f.(state)
      end
    end
  end

  @doc """
  Starts a `FunServer` process without links (outside of a supervision tree)

  _For more information please refer to `GenServer.start/3`_
  """
  @spec start(module :: atom(), init_handler(), options :: GenServer.options()) ::
          {:ok, pid()} | {:error, any()} | :ignore
  def start(module, init_handler, options \\ [])

  def start(module, {m, f, a} = handler, options) when is_atom(m) and is_atom(f) and is_list(a) do
    GenServer.start(module, handler, options)
  end

  def start(module, handler, options) when is_function(handler) do
    GenServer.start(module, handler, options)
  end

  @doc """
  Starts a `FunServer` process linked to the current 'caller' process.

  _For more information please refer to `GenServer.start_link/3`_
  """
  @spec start_link(module :: atom(), init_handler(), options :: GenServer.options()) ::
          {:ok, pid()} | {:error, any()} | :ignore
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
          handler :: sync_handler(),
          server :: GenServer.server(),
          timeout :: timeout()
        ) :: term()
  def sync(handler, server, timeout \\ 5_000)

  def sync({m, f, a} = handler, server, timeout) when is_atom(m) and is_atom(f) and is_list(a) do
    GenServer.call(server, handler, timeout)
  end

  def sync(handler, server, timeout) when is_function(handler) do
    GenServer.call(server, handler, timeout)
  end

  @doc """
  Executes an asynchronous call to the `server`.
  Works very similar to how a `GenServer.cast/2` function works, but instead of passing message
  which is later handled in a `handle_cast/2` callback, a function is passed, which gets evaluated
  on the `server`.

  _For additional information please refer to `GenServer.cast/2`_
  """
  @spec async(handler :: async_handler(), server :: GenServer.server()) :: term()
  def async({m, f, a} = handler, server) when is_atom(m) and is_atom(f) and is_list(a) do
    GenServer.cast(server, handler)
  end

  def async(handler, server) when is_function(handler) do
    GenServer.cast(server, handler)
  end
end
