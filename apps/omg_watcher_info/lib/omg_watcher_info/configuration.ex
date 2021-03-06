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

defmodule OMG.WatcherInfo.Configuration do
  @moduledoc """
  Provides access to applications configuration
  """
  @app :omg_watcher_info

  def pending_block_processing_interval() do
    Application.fetch_env!(@app, :pending_block_processing_interval)
  end

  def block_queue_check_interval() do
    Application.fetch_env!(@app, :block_queue_check_interval)
  end
end
