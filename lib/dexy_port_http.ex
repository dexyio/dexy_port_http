defmodule DexyPortHTTP do

  use Application

  defmodule Supervisor do
    use DexyLib.Supervisor, otp_app: :dexy_port_http
  end

  require Logger

  def start(_type, _args) do
    compile_dispatch |> start_server
    opts = [strategy: :one_for_one, name: __MODULE__.Supervisor]
    Supervisor.start_link(opts)
  end

  def config do
    Application.get_env(:dexy_port_http, __MODULE__)
  end

  @default_pool_size 10

  def start_server dispatch do
    http_handler = config[:handler] || (
      Logger.warn "handler: not configured, default: #{__MODULE__.Handler}";
      __MODULE__.Handler
    )
    pool_size = config[:pool_size] || (
      Logger.warn "pool_size: not configured, default: #{@default_pool_size}";
      @default_pool_size
    )
    protocols = config[:protocols] || throw :protocols_not_configured
    {:ok, _pid} = :cowboy.start_tls http_handler, pool_size, protocols[:https], %{
      env: %{dispatch: dispatch}
    }
  end

  @default_dispatch [
    {:_, [{:_, __MODULE__.Handler, []}]}
  ]

  defp compile_dispatch do
    dispatch = config[:dispatch] || (
      Logger.warn "dispatch: not_configured, default: #{inspect @default_dispatch}";
      @default_dispatch
    )
    :cowboy_router.compile dispatch
  end

end
