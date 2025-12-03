defmodule Mix.Tasks.CreateSuperuser do
  use Mix.Task

  alias Levanngoc.Accounts.User
  alias Levanngoc.Billing
  alias Levanngoc.Repo

  @shortdoc "Creates a new superuser account"
  @moduledoc """
  Creates a new superuser account with email, password, and password confirmation.
  The role will be set to superuser (999999).
  """

  def run(_args) do
    Mix.Task.run("app.start")

    email = prompt_for_email()
    password = prompt_for_password()
    password_confirmation = prompt_for_password_confirmation()

    if password != password_confirmation do
      Mix.shell().error("Lỗi: Mật khẩu và xác nhận mật khẩu không khớp.")
      System.halt(1)
    end

    # Validate password strength
    case validate_password_strength(password) do
      {:error, message} ->
        Mix.shell().error("Lỗi: #{message}")
        System.halt(1)

      :ok ->
        # Create the user
        create_superuser(email, password)
    end
  end

  defp prompt_for_email do
    email =
      IO.gets("Enter email: ")
      |> String.trim()

    if email == "" do
      Mix.shell().error("Lỗi: Email không được để trống.")
      System.halt(1)
    end

    # Kiểm tra định dạng email cơ bản
    unless valid_email_format?(email) do
      Mix.shell().error("Lỗi: Định dạng email không hợp lệ.")
      System.halt(1)
    end

    email
  end

  defp prompt_for_password do
    case IO.gets("Password: ") do
      {:error, :arguments} ->
        Mix.shell().error("Error reading password input")
        System.halt(1)

      nil ->
        Mix.shell().error("Error reading password input")
        System.halt(1)

      password_input ->
        password = String.trim(password_input)

        if password == "" do
          Mix.shell().error("Lỗi: Mật khẩu không được để trống.")
          System.halt(1)
        end

        password
    end
  end

  defp prompt_for_password_confirmation do
    case IO.gets("Xác nhận mật khẩu: ") do
      {:error, :arguments} ->
        Mix.shell().error("Error reading password confirmation input")
        System.halt(1)

      nil ->
        Mix.shell().error("Error reading password confirmation input")
        System.halt(1)

      confirmation_input ->
        String.trim(confirmation_input)
    end
  end

  defp valid_email_format?(email) do
    # Basic email validation regex
    Regex.match?(~r/^[^@,;\s]+@[^@,;\s]+$/, email)
  end

  defp validate_password_strength(password) do
    cond do
      String.length(password) < 8 ->
        {:error, "Mật khẩu phải có ít nhất 8 ký tự"}

      String.length(password) > 72 ->
        {:error, "Mật khẩu không được vượt quá 72 ký tự"}

      true ->
        :ok
    end
  end

  defp create_superuser(email, password) do
    # Check if user already exists
    case Repo.get_by(User, email: email) do
      nil ->
        # Get the free plan to assign to the superuser
        free_plan = Billing.get_free_plan()

        # Create new superuser with role 999999 (superuser based on the get_role function)
        attrs = %{
          email: email,
          password: password,
          role: 999_999
        }

        # Create user with email and password changesets, confirming the account immediately
        %User{}
        |> User.email_changeset(attrs, validate_unique: false)
        |> User.password_changeset(attrs, hash_password: true)
        |> Ecto.Changeset.put_change(:role, 999_999)
        |> Ecto.Changeset.put_change(
          :confirmed_at,
          DateTime.truncate(DateTime.utc_now(), :second)
        )
        # Only assign billing plan if it exists
        |> maybe_assign_billing_plan(free_plan)
        |> Repo.insert()
        |> handle_insert_result(email)

      _existing_user ->
        Mix.shell().error("Lỗi: Người dùng với email #{email} đã tồn tại.")
        System.halt(1)
    end
  end

  defp maybe_assign_billing_plan(changeset, free_plan) when not is_nil(free_plan) do
    changeset
    |> Ecto.Changeset.put_change(:billing_price_id, free_plan.id)
    |> Ecto.Changeset.put_change(:token_amount, free_plan.token_amount_provide)
  end

  defp maybe_assign_billing_plan(changeset, _free_plan) do
    # If no free plan, just ensure token_amount is set
    changeset
    |> Ecto.Changeset.put_change(:token_amount, 0)
  end

  defp handle_insert_result({:ok, user}, email) do
    Mix.shell().info(IO.ANSI.format([:green, "Tạo superuser thành công với email: #{email}"]))

    Mix.shell().info(IO.ANSI.format([:green, "Vai trò người dùng: superuser (#{user.role})"]))
  end

  defp handle_insert_result({:error, changeset}, _email) do
    Mix.shell().error("Lỗi khi tạo superuser:")

    changeset_errors =
      changeset.errors
      |> Enum.map(fn {field, {message, _opts}} ->
        "#{field}: #{message}"
      end)

    Enum.each(changeset_errors, fn error ->
      Mix.shell().error("- #{error}")
    end)

    System.halt(1)
  end
end
