# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

app = :dexy_port_http
http_handler = DexyPortHTTP.Handler

config app, DexyPortHTTP,
  handler: http_handler,
  dispatch: [
    {:_, [{:_, http_handler, []}]}
  ],
  pool_size: 100,
  protocols: [https: [
    port: 443,
    certfile: 'priv/ssl/certificate.crt',
    keyfile: 'priv/ssl/private.key'
  ]]

config app, DexyPortHTTP.Handler,
  engine_node: :"dex@127.0.0.1",
  engine_module: Dex.Service,
  engine_function: :route
