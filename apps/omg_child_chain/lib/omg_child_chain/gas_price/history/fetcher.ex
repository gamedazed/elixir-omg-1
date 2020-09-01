# Copyright 2020 OmiseGO Pte Ltd
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

defmodule OMG.ChildChain.GasPrice.History.Fetcher do
  @moduledoc """
  Provides functions to stream-fetch block history from an Ethereum client.
  """
  require Logger

  alias Ethereumex.HttpClient
  alias OMG.Eth.Encoding

  # Too large a batch and the Eth client will time out, especially because we are
  # requesting for all transaction info in each block. Use a number that we are certain
  # the client is able to serve or within `@retries`.
  @per_batch 20

  @retries 5
  @retry_ms 10_000

  @doc """
  Prepares a stream that fetches the gas prices within the given heights.

  Internally this function fetches the input `heights` in batches of #{@per_batch} blocks.
  """
  @spec stream(Range.t(), String.t()) :: Enumerable.t()
  def stream(heights, ethereum_url) do
    heights
    |> Stream.chunk_every(@per_batch)
    |> Stream.flat_map(fn heights ->
      _ = Logger.info("Fetching heights #{inspect(hd(heights))} - #{inspect(Enum.at(heights, -1))}...")

      {:ok, results} =
        heights
        |> Enum.map(fn height -> {:eth_get_block_by_number, [Encoding.to_hex(height), true]} end)
        |> batch_request(ethereum_url)

      results
    end)
  end

  defp batch_request(requests, ethereum_url, retries \\ @retries)

  defp batch_request(requests, ethereum_url, 1) do
    _ = Logger.warn("Last attempt to batch request: #{inspect(requests)}")
    HttpClient.batch_request(requests, url: ethereum_url)
  end

  defp batch_request(requests, ethereum_url, retries) do
    case HttpClient.batch_request(requests, url: ethereum_url) do
      {:error, _} = response ->
        _ =
          Logger.warn("""
          Batch request failed. Retrying in #{inspect(@retry_ms)}ms with #{inspect(retries - 1)} retries left.

          Request: #{inspect(requests)}

          Response: #{inspect(response)}
          """)

        _ = Process.sleep(@retry_ms)
        batch_request(requests, retries - 1)

      response ->
        response
    end
  end
end
