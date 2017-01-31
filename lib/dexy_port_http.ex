defmodule DexyPortHTTP do

  use Application

  defmodule Supervisor do
    use DexyLib.Supervisor, otp_app: :dexy_port_http
  end

  require Logger

  def start(_type, _args) do
    compile_dispatch() |> start_server
    opts = [strategy: :one_for_one, name: __MODULE__.Supervisor]
    Supervisor.start_link(opts)
  end

  def config do
    Application.get_env(:dexy_port_http, __MODULE__)
  end

  @default_pool_size 10
  @default_start_opts [
    max_header_name_length: 64,
    max_header_value_length: 4096,
    max_headers: 100,
    max_keepalive: 100,
    max_method_length: 64,
    request_timeout: 300_000,
  ]

  def start_server dispatch do
    pool_size = config()[:pool_size] || (
      Logger.warn "pool_size: not configured, default: #{@default_pool_size}";
      @default_pool_size
    )
    start_opts = config()[:start_opts] || (
      Logger.warn "start_opts: not configured, default: #{@default_start_opts}";
      @default_start_opts 
    )
    start_opts = start_opts |> Enum.into(%{}) |> Map.merge(%{env: %{dispatch: dispatch}})
    protocols = config()[:protocols] || throw :protocols_not_configured
    {:ok, _pid} = :cowboy.start_clear :dexy_port_http, pool_size, protocols[:http], start_opts
    {:ok, _pid} = :cowboy.start_tls :dexy_port_https, pool_size, protocols[:https], start_opts
  end

  @default_dispatch [
    {:_, [{:_, __MODULE__.Handler, []}]}
  ]

  defp compile_dispatch do
    dispatch = config()[:dispatch] || (
      Logger.warn "dispatch: not_configured, default: #{inspect @default_dispatch}";
      @default_dispatch
    )
    :cowboy_router.compile dispatch
  end

end
