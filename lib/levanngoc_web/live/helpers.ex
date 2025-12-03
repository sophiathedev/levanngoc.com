defmodule LevanngocWeb.LiveHelpers do
  @moduledoc """
  Common helpers for LiveView modules
  """

  def humanize_size(size) do
    cond do
      size < 1024 -> "#{size} B"
      size < 1024 * 1024 -> "#{Float.round(size / 1024, 2)} KB"
      true -> "#{Float.round(size / (1024 * 1024), 2)} MB"
    end
  end

  def error_to_string(:too_large), do: "File quá lớn (Max 32MB)"
  def error_to_string(:too_many_files), do: "Chỉ được upload 1 file"
  def error_to_string(:not_accepted), do: "Định dạng file không hợp lệ"
  def error_to_string(_), do: "Có lỗi xảy ra"
end
