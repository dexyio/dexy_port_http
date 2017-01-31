defmodule DexyPortHTTP.Handler do

  require Logger

  @app :dexy_port_http
  @engine_node Application.get_env(@app, __MODULE__)[:engine_node]
    || throw "engine_node: not configured"
  @engine_module Application.get_env(@app, __MODULE__)[:engine_module]
    || throw "engine_module: not configured"
  @engine_function Application.get_env(@app, __MODULE__)[:engine_function]
    || throw "engine_function: not configured"

  def init(req, state) do
    req = request(req) |> await |> reply(req)
    {:ok, req, state}
  end

  defp request req do
    {app, args} = parse_path req
    {peer, remote_ip} = peer_and_remoteip req
    {fun, opts} = fun_and_opts req
    [
      user: user(req),
      app: app,
      fun: fun,
      args: args,
      opts: opts,
      header: req.headers,
      body: body(req),
      callback: self(),
      peer: peer,
      remote_ip: remote_ip
    ] |> do_request
  end

  defp do_request props do
    Logger.debug inspect props
    case :rpc.call @engine_node, @engine_module, @engine_function, [props] do
      {:ok, res} -> res[:rid]
      {:error, _reason} = err -> err
    end
  end

  defp await {:error, :user_notfound} do
    http_response code: 404, body: "UserNotFound"
  end

  defp await {:error, :user_disabled} do
    http_response code: 404, body: "UserDisabled"
  end

  defp await rid do
    receive do
      {^rid, {:ok, res}} -> Logger.debug (inspect ok: res)
        set_response res
      {^rid, {:notify, msg}} -> Logger.debug (inspect notify: msg)
        await(rid)
      {^rid, {:error, error}} -> Logger.info (inspect error: error)
        http_response code: error.code, body: to_json error
    after
      300_000 -> http_response code: 408, body: "RequestTimeout"
    end
  end

  defp set_response(res) when is_bitstring(res) do
    http_response code: 200, body: res, header: %{
      "content-type" => "text/plain"
    }
  end

  defp set_response(res) when is_atom(res) or is_number(res) do
    http_response code: 200, body: res |> to_string, header: %{
      "content-type" => "text/plain"
    }
  end

  defp set_response(res = _.._) do
    http_response code: 200, body: res |> Enum.to_list, header: %{
      "content-type" => "text/plain"
    }
  end

  defp set_response %{"code" => code, "body" => body, "header" => header} do
    http_response code: code, body: body |> to_json, header: header
  end

  defp set_response res do
    http_response code: 200, body: res |> to_json, header: %{
      "content-type" => "application/json"
    }
  end

  defp reply %{code: code, header: header, body: body}, req do
    :cowboy_req.reply code, header, body, req
  end

  defp to_json(data) when is_bitstring(data), do: data
  defp to_json(data) do
    case DexyLib.JSON.encode data do
      {:ok, val} -> val
      {:error, _} -> inspect data
    end
  end

  defp http_response props do
    %{
      code: props[:code] || 200,
      body: props[:body] || "",
      header: props[:header] || %{}
    }
  end

  defp user req do
    req |> :cowboy_req.host |> String.split(".", parts: 3)
    |> case do
      [user, _, _ | _] -> user
      _ -> ""
    end
  end

  defp body req do
    case :cowboy_req.has_body(req) do
      false -> ""
      true -> :cowboy_req.header("content-type", req) |> do_body(req)
    end
  end

  defp do_body "application/x-www-form-urlencoded", req do
    {:ok, key_values, _req} = :cowboy_req.read_urlencoded_body req
    key_values
  end

  defp do_body _, req do
    {:ok, body, _req} = :cowboy_req.read_body req
    body
  end

  defp peer_and_remoteip %{peer: {ip, port}} do
    peer = %{
      ip: ip |> Tuple.to_list,
      port: port
    }
    remote_ip = peer.ip
    {peer, remote_ip}
  end

  defp fun_and_opts %{method: method, qs: qs} do
    params = URI.decode_query  qs
    case Map.pop params, "_fun" do
      {nil, opts} -> {method |> String.downcase, opts}
      {fun, opts} -> {fun, opts}
    end
  end

  defp parse_path %{path: path} do
    path |> String.split("/") |> do_parse_path
  end

  defp do_parse_path ["", ""] do {"", []} end 
  defp do_parse_path ["", app] do {app, []} end 

  defp do_parse_path ["", app | args] do
    args = Enum.map args, &URI.decode(&1)
    {app, args}
  end

end
