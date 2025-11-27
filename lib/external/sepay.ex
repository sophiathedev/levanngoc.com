defmodule Levanngoc.External.Sepay do
  def build_params(%{
        merchant: merchant_id,
        secret_key: secret_key,
        order_amount: order_amount,
        order_description: order_description,
        order_invoice_number: invoice_number,
        customer_id: customer_id,
        success_url: success_url
      }) do
    params = %{
      "merchant" => merchant_id,
      "operation" => "PURCHASE",
      "order_amount" => to_string(order_amount),
      "currency" => "VND",
      "order_invoice_number" => invoice_number,
      "order_description" => order_description,
      "customer_id" => customer_id,
      "success_url" => success_url
    }

    keys = [
      "merchant",
      "operation",
      "order_amount",
      "currency",
      "order_invoice_number",
      "order_description",
      "customer_id",
      "success_url"
    ]

    signature_string =
      keys
      |> Enum.map_join(",", fn k -> "#{k}=#{params[k]}" end)

    signature =
      :crypto.mac(:hmac, :sha256, secret_key, signature_string) |> Base.encode64()

    keys
    |> Enum.map(fn k -> {k, params[k]} end)
    |> List.insert_at(-1, {"signature", signature})
  end
end
