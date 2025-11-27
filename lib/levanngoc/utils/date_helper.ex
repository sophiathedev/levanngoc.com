defmodule Levanngoc.Utils.DateHelper do
  @moduledoc """
  Utility functions for working with Date and DateTime.
  """

  @doc """
  Adds a number of months to a DateTime, preserving the day of the month as much as possible.
  If the target month has fewer days, it clamps to the last day of that month.
  """
  def shift_months(datetime, months) do
    total_months = datetime.year * 12 + datetime.month - 1 + months
    year = div(total_months, 12)
    month = rem(total_months, 12) + 1
    day = min(datetime.day, Calendar.ISO.days_in_month(year, month))

    %{datetime | year: year, month: month, day: day}
  end
end
