# Copyright 2019-2020 OmiseGO Pte Ltd
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

defmodule OMG.WatcherRPC.Web.Endpoint do
  use Sentry.PlugCapture
  use Phoenix.Endpoint, otp_app: :omg_watcher_rpc

  plug(OMG.Utils.RemoteIP)
  plug(Plug.RequestId)
  plug(Plug.Logger, log: :debug)
  plug(Plug.Telemetry, event_prefix: [:watcher_rpc, :endpoint])

  if code_reloading? do
    plug(Phoenix.CodeReloader)
  end

  plug(
    Plug.Parsers,
    parsers: [:json],
    pass: [],
    json_decoder: Jason
  )

  plug(Sentry.PlugContext)
  plug(Plug.MethodOverride)
  plug(Plug.Head)

  if Application.get_env(:omg_watcher_rpc, OMG.WatcherRPC.Web.Endpoint)[:enable_cors],
    do: plug(CORSPlug)

  plug(OMG.WatcherRPC.Web.Plugs.MethodParamFilter)
  plug(OMG.WatcherRPC.Web.Router)
end
