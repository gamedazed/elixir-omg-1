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

defmodule OMG.ChildChain.GasPrice.Strategy.PoissonGasStrategy.Algorithm do
  @moduledoc """
  The algorithmic functions for PoissonGasStrategy.

  Note that the internal unit used in this strategy is 10 Gwei, and therefore internal conversions
  from wei are based on 1e8 (`100_000_000`) instead of the usual 1e9 (`1_000_000_000`).

  The return of public functions, however, are already converted back to wei.
  """

  # Note that the division by 1e8 instead of 1e9 here is intentional.
  # The unit is per 10 Gwei, which aligns with `@prediction_table_ranges`.
  # See: https://github.com/ethgasstation/gasstation-express-oracle/blob/3cfb354/gasExpress.py#L48
  @wei_to_10gwei 100_000_000

  # 1, 2, 3, .., 10, 20, 30, .., 1010
  @prediction_table_ranges :lists.seq(0, 9, 1) ++ :lists.seq(10, 1010, 10)

  @doc """
  Analyzes historical blocks. Returns the lowest minimum gas price found in a block,
  the highest minimum gas price found in a block, and the percentage of blocks accepted
  per each minimum gas price seen.

  Equivalent to [gasExpress.py's `analyze_last200blocks()`](https://github.com/ethgasstation/gasstation-express-oracle/blob/3cfb354/gasExpress.py#L119-L134)
  """
  def analyze_blocks(price_history) do
    # [min_price1, min_price2, min_price3, ...]
    sorted_min_prices =
      price_history
      |> remove_empty()
      |> extract_min_prices()
      |> round_10gwei()
      |> Enum.sort()

    num_blocks = length(sorted_min_prices)
    lowest_min_price = Enum.at(sorted_min_prices, 0)
    highest_min_price = Enum.at(sorted_min_prices, -1)

    # %{min_price => num_blocks_accepted}
    num_blocks_by_min_prices = Enum.frequencies(sorted_min_prices)

    # %{min_price => cumulative_num_blocks_accepted}
    cumulative_sum = cumulative_sum(num_blocks_by_min_prices)

    # %{min_price => hash_percentage}
    hash_percentages = Enum.map(cumulative_sum, fn {min_price, cumsum} -> {min_price, cumsum / num_blocks * 100} end)

    {hash_percentages, lowest_min_price, highest_min_price}
  end

  @doc """
  Generates the gas price prediction table based on the historical hash percentages.

  Equivalent to [gasExpress.py's `make_predictTable()`](https://github.com/ethgasstation/gasstation-express-oracle/blob/3cfb354/gasExpress.py#L137-L145)
  """
  def make_prediction_table(hash_percentages, lowest_min_price, highest_min_price) do
    Enum.into(@prediction_table_ranges, [], fn gas_price ->
      hpa =
        cond do
          gas_price > highest_min_price -> 100
          gas_price < lowest_min_price -> 0
          true -> get_hpa(hash_percentages, gas_price)
        end

      {gas_price, hpa}
    end)
  end

  @doc """
  Converts the gas price prediction table into easily digestible thresholds.

  Equivalent to [gasExpress.py's `get_gasprice_recs()`](https://github.com/ethgasstation/gasstation-express-oracle/blob/3cfb354/gasExpress.py#L147-L176)
  """
  def get_recommendations(thresholds, prediction_table) do
    Enum.map(thresholds, fn {threshold_name, threshold_value} ->
      suggested_price =
        case Enum.find(prediction_table, fn {_gas_price, hpa} -> hpa >= threshold_value end) do
          nil -> nil
          {gas_price, _hpa} -> gas_price / 10
        end

      {threshold_name, suggested_price}
    end)
  end

  defp remove_empty(history) do
    Enum.reject(history, fn {_height, prices, _timestamp} -> Enum.empty?(prices) end)
  end

  defp extract_min_prices(history) do
    Enum.map(history, fn {_height, prices, _timestamp} -> Enum.min(prices) end)
  end

  defp round_10gwei(prices) when is_list(prices) do
    Enum.map(prices, &round_10gwei/1)
  end

  # https://github.com/ethgasstation/gasstation-express-oracle/blob/3cfb354/gasExpress.py#L46-L57
  defp round_10gwei(price) do
    case price / @wei_to_10gwei do
      gp when gp >= 1 and gp < 10 ->
        floor(gp)

      gp when gp >= 10 ->
        floor(gp / 10) * 10

      _ ->
        0
    end
  end

  defp cumulative_sum(values) do
    values
    |> Enum.scan(fn {min_price, num_blocks}, {_previous_min_price, previous_cumsum} ->
      {min_price, num_blocks + previous_cumsum}
    end)
    |> Enum.into(%{})
  end

  defp get_hpa(hash_percentages, gas_price) do
    hash_percentages
    |> Enum.filter(fn {min_price, _} -> gas_price >= min_price end)
    |> Enum.map(&elem(&1, 1))
    |> Enum.max()
  end
end