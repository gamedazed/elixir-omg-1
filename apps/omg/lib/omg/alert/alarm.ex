# Copyright 2019 OmiseGO Pte Ltd
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

defmodule OMG.Alert.Alarm do
  @moduledoc """
  Interface for raising and clearing alarms.
  """
  alias OMG.Alert.AlarmHandler

  @typedoc """
  The raw alarm being used to `set` the Alarm
  """
  @type raw_t ::
          {:boot_in_progress
           | :ethereum_client_connection
           | :invalid_fee_file, node(), module()}

  def ethereum_client_connection_issue(node, reporter),
    do: {:ethereum_client_connection, %{node: node, reporter: reporter}}

  def boot_in_progress(node, reporter),
    do: {:boot_in_progress, %{node: node, reporter: reporter}}

  def invalid_fee_file(node, reporter),
    do: {:invalid_fee_file, %{node: node, reporter: reporter}}

  @spec set(raw_t()) :: :ok | :duplicate
  def set(raw_alarm), do: raw_alarm |> make_alarm() |> do_raise()

  @spec clear(raw_t()) :: :ok | :not_raised
  def clear(raw_alarm), do: raw_alarm |> make_alarm() |> do_clear()

  def clear_all do
    all_raw()
    |> Enum.each(&:alarm_handler.clear_alarm(&1))
  end

  def all do
    all_raw()
    |> Enum.map(&format_alarm/1)
  end

  defp do_raise(alarm) do
    if Enum.member?(all_raw(), alarm),
      do: :duplicate,
      else: :alarm_handler.set_alarm(alarm)
  end

  defp do_clear(alarm) do
    if Enum.member?(all_raw(), alarm),
      do: :alarm_handler.clear_alarm(alarm),
      else: :not_raised
  end

  defp format_alarm({id, details}), do: %{id: id, details: details}
  defp format_alarm(alarm), do: %{id: alarm}

  defp all_raw, do: :gen_event.call(:alarm_handler, AlarmHandler, :get_alarms)

  @spec make_alarm(raw_t()) :: {atom(), %{node: node(), reporter: module()}}
  defp make_alarm(raw_alarm = {_, node, reporter}) when is_atom(node) and is_atom(reporter),
    do: make_alarm_for(raw_alarm)

  defp make_alarm_for({:ethereum_client_connection, node, reporter}) do
    ethereum_client_connection_issue(node, reporter)
  end

  defp make_alarm_for({:boot_in_progress, node, reporter}) do
    boot_in_progress(node, reporter)
  end

  defp make_alarm_for({:invalid_fee_file, node, reporter}) do
    invalid_fee_file(node, reporter)
  end
end
