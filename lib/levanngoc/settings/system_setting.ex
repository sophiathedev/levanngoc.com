defmodule Levanngoc.Settings.AdminSetting do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "admin_settings" do
    field :scraping_dog_api_key, :string
    field :mailgun_api_key, :string
    field :proxy_host, :string
    field :proxy_port, :integer
    field :proxy_username, :string
    field :proxy_password, :string
    field :sepay_merchant_id, :string
    field :sepay_api_key, :string
    field :token_usage_check_url_index, :integer
    field :token_usage_check_allintitle, :integer
    field :token_usage_keyword_ranking, :integer

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(admin_setting, attrs) do
    admin_setting
    |> cast(attrs, [
      :scraping_dog_api_key,
      :mailgun_api_key,
      :proxy_host,
      :proxy_port,
      :proxy_username,
      :proxy_password,
      :sepay_merchant_id,
      :sepay_api_key,
      :token_usage_check_url_index,
      :token_usage_check_allintitle,
      :token_usage_keyword_ranking
    ])
    |> validate_length(:scraping_dog_api_key, max: 1024)
    |> validate_length(:mailgun_api_key, max: 1024)
    |> validate_length(:proxy_host, max: 255)
    |> validate_number(:proxy_port, greater_than: 0, less_than_or_equal_to: 65535)
    |> validate_length(:proxy_username, max: 255)
    |> validate_length(:proxy_password, max: 255)
    |> validate_length(:sepay_merchant_id, max: 512)
    |> validate_length(:sepay_api_key, max: 512)
    |> validate_number(:token_usage_check_url_index, greater_than: 0)
    |> validate_number(:token_usage_check_allintitle, greater_than: 0)
    |> validate_number(:token_usage_keyword_ranking, greater_than: 0)
  end
end
