# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

app = :dexy_port_http
http_handler = DexyPortHTTP.Handler

config app, DexyPortHTTP,
  dispatch: [
    {:_, [{:_, http_handler, []}]}
  ],
  pool_size: 100,
  start_opts: [
    max_header_name_length: 64,
    max_header_value_length: 4096,
    max_headers: 100,
    max_keepalive: 100,
    max_method_length: 64,
    request_timeout: 300_000,
  ],
  protocols: [
    http: [
      port: 8080,
    ],
    https: [
      port: 443,
      cacertfile: 'priv/ssl/ca_bundle.crt',
      certfile: 'priv/ssl/certificate.crt',
      keyfile: 'priv/ssl/private.key'
    ]
  ]

config app, DexyPortHTTP.Handler, [
  engine_node: :"dex@127.0.0.1",
  engine_module: Dex.Service,
  engine_function: :route,
  loop_timeout: 300_000
]
