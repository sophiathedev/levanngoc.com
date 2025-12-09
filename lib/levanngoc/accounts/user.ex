defmodule Levanngoc.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "users" do
    field :email, :string
    field :password, :string, virtual: true, redact: true
    field :hashed_password, :string, redact: true
    field :confirmed_at, :utc_datetime
    field :authenticated_at, :utc_datetime, virtual: true
    field :role, :integer, default: 0
    field :banned_at, :utc_datetime
    field :token_amount, :integer, default: 0
    field :is_active, :boolean, default: false

    belongs_to :billing_price, Levanngoc.Billing.BillingPrice
    has_many :billing_histories, Levanngoc.Billing.BillingHistory
    has_one :current_billing, Levanngoc.Billing.BillingHistory, where: [is_current: true]
    has_many :keyword_checkings, Levanngoc.KeywordChecking
    has_many :popup_seens, Levanngoc.PopupSeen

    timestamps(type: :utc_datetime)
  end

  @doc """
  A user changeset for registering or changing the email.

  It requires the email to change otherwise an error is added.

  ## Options

    * `:validate_unique` - Set to false if you don't want to validate the
      uniqueness of the email, useful when displaying live validations.
      Defaults to `true`.
  """
  def email_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email])
    |> validate_email(opts)
  end

  defp validate_email(changeset, opts) do
    changeset =
      changeset
      |> validate_required([:email])
      |> validate_format(:email, ~r/^[^@,;\s]+@[^@,;\s]+$/,
        message: "phải có dấu @ và không có khoảng trắng"
      )
      |> validate_length(:email, max: 160)

    if Keyword.get(opts, :validate_unique, true) do
      changeset
      |> unsafe_validate_unique(:email, Levanngoc.Repo)
      |> unique_constraint(:email, message: "đã được sử dụng")
      |> validate_email_changed()
    else
      changeset
    end
  end

  defp validate_email_changed(changeset) do
    if get_field(changeset, :email) && get_change(changeset, :email) == nil do
      add_error(changeset, :email, "email không được thay đổi")
    else
      changeset
    end
  end

  @doc """
  A user changeset for changing the password.

  It is important to validate the length of the password, as long passwords may
  be very expensive to hash for certain algorithms.

  ## Options

    * `:hash_password` - Hashes the password so it can be stored securely
      in the database and ensures the password field is cleared to prevent
      leaks in the logs. If password hashing is not needed and clearing the
      password field is not desired (like when using this changeset for
      validations on a LiveView form), this option can be set to `false`.
      Defaults to `true`.
  """
  def password_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:password])
    |> validate_confirmation(:password, message: "mật khẩu không khớp")
    |> validate_password(opts)
  end

  defp validate_password(changeset, opts) do
    changeset
    |> validate_required([:password])
    |> validate_length(:password, min: 8, max: 72)
    # Examples of additional password validation:
    # |> validate_format(:password, ~r/[a-z]/, message: "at least one lower case character")
    # |> validate_format(:password, ~r/[A-Z]/, message: "at least one upper case character")
    # |> validate_format(:password, ~r/[!?@#$%^&*_0-9]/, message: "at least one digit or punctuation character")
    |> maybe_hash_password(opts)
  end

  defp maybe_hash_password(changeset, opts) do
    hash_password? = Keyword.get(opts, :hash_password, true)
    password = get_change(changeset, :password)

    if hash_password? && password && changeset.valid? do
      changeset
      # If using Bcrypt, then further validate it is at most 72 bytes long
      |> validate_length(:password, max: 72, count: :bytes)
      # Hashing could be done with `Ecto.Changeset.prepare_changes/2`, but that
      # would keep the database transaction open longer and hurt performance.
      |> put_change(:hashed_password, Bcrypt.hash_pwd_salt(password))
      |> delete_change(:password)
    else
      changeset
    end
  end

  @doc """
  Confirms the account by setting `confirmed_at`.
  """
  def confirm_changeset(user) do
    now = DateTime.utc_now(:second)
    change(user, confirmed_at: now)
  end

  @doc """
  A user changeset for admin updates (role, tokens, ban, active status).
  """
  def admin_changeset(user, attrs) do
    user
    |> cast(attrs, [:role, :token_amount, :banned_at, :is_active])
    |> validate_inclusion(:role, [0, 999_999])
  end

  @doc """
  A user changeset for admin password updates.
  Does not require current password validation.
  """
  def admin_password_changeset(user, attrs) do
    user
    |> cast(attrs, [:password])
    |> validate_confirmation(:password, message: "Mật khẩu không khớp")
    |> validate_required([:password], message: "không được để trống")
    |> validate_length(:password, min: 8, message: "phải có ít nhất 8 ký tự")
    |> validate_length(:password, max: 72, message: "không được quá 72 ký tự")
    |> maybe_hash_password(hash_password: true)
  end

  @doc """
  Verifies the password.

  If there is no user or the user doesn't have a password, we call
  `Bcrypt.no_user_verify/0` to avoid timing attacks.
  """
  def valid_password?(%Levanngoc.Accounts.User{hashed_password: hashed_password}, password)
      when is_binary(hashed_password) and byte_size(password) > 0 do
    Bcrypt.verify_pass(password, hashed_password)
  end

  def valid_password?(_, _) do
    Bcrypt.no_user_verify()
    false
  end

  @doc """
  Returns the role as an atom based on the user's role integer value.

  ## Examples

      iex> get_role(%User{role: 999999})
      :superuser

      iex> get_role(%User{role: 0})
      :normal

  """
  def get_role(%__MODULE__{role: 999_999}), do: :superuser
  def get_role(%__MODULE__{role: 0}), do: :normal
  def get_role(%__MODULE__{}), do: :normal

  @doc """
  Checks if the user is a superuser.

  ## Examples

      iex> superuser?(%User{role: 999999})
      true

      iex> superuser?(%User{role: 0})
      false

  """
  def superuser?(%__MODULE__{} = user), do: get_role(user) == :superuser
  def superuser?(nil), do: false
end
