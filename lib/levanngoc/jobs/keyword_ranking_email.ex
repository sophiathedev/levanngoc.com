defmodule Levanngoc.Jobs.KeywordRankingEmail do
  @moduledoc """
  Oban worker that sends keyword ranking report emails at scheduled times.

  This job processes keyword rankings and sends the report via email
  with an Excel attachment to the user.
  """
  use Oban.Worker, queue: :default

  alias Levanngoc.Repo
  alias Levanngoc.Settings.AdminSetting
  alias Levanngoc.KeywordCheckings
  alias Levanngoc.Accounts.UserNotifier
  alias Levanngoc.Accounts

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id, "hour" => hour, "minute" => minute}}) do
    Logger.info("Starting keyword ranking email job for user #{user_id}")

    # Load user
    user = Levanngoc.Accounts.get_user!(user_id)

    # Get admin settings for ScrapingDog API key
    admin_setting = Repo.all(AdminSetting) |> List.first()

    case admin_setting do
      %AdminSetting{
        scraping_dog_api_key: api_key,
        token_usage_keyword_ranking: token_usage_keyword_ranking
      }
      when is_binary(api_key) and api_key != "" ->
        # Get all keyword checkings to process
        keyword_checkings = KeywordCheckings.list_keyword_checkings(user.id)

        if Enum.empty?(keyword_checkings) do
          Logger.info("User #{user_id}: No keywords to check")
          {:ok, :no_keywords}
        else
          # Calculate total token cost
          total_keywords = length(keyword_checkings)
          token_cost = total_keywords * (token_usage_keyword_ranking || 0)
          current_token_amount = user.token_amount || 0

          # Check if user has enough tokens
          if current_token_amount < token_cost do
            # User doesn't have enough tokens, send notification email
            Logger.warning(
              "User #{user_id}: Insufficient tokens. Required: #{token_cost}, Current: #{current_token_amount}"
            )

            missing_tokens = current_token_amount - token_cost

            # Generate full billing URL
            billing_url = LevanngocWeb.Endpoint.url() <> "/users/billing"

            # Send insufficient tokens notification
            case UserNotifier.deliver_insufficient_tokens_notification(user, %{
                   required_tokens: token_cost,
                   current_tokens: current_token_amount,
                   missing_tokens: missing_tokens,
                   billing_url: billing_url
                 }) do
              {:ok, _email} ->
                Logger.info(
                  "User #{user_id}: Insufficient tokens notification email sent successfully"
                )

              {:error, reason} ->
                Logger.error(
                  "User #{user_id}: Failed to send insufficient tokens email - #{inspect(reason)}"
                )
            end

            # Do not schedule next job - user needs to manually restart after adding tokens
            Logger.info("User #{user_id}: Scheduled email job stopped due to insufficient tokens")

            {:ok, :insufficient_tokens}
          else
            # User has enough tokens, process keyword rankings
            # Process keyword rankings
            start_time = DateTime.utc_now()

            scraping_dog =
              %Levanngoc.External.ScrapingDog{}
              |> Levanngoc.External.ScrapingDog.put_apikey(api_key)

            results =
              keyword_checkings
              |> Task.async_stream(
                fn keyword_checking ->
                  rank =
                    Levanngoc.External.ScrapingDog.check_keyword_ranking(
                      scraping_dog,
                      keyword_checking.keyword,
                      keyword_checking.website_url
                    )

                  %{
                    keyword: keyword_checking.keyword,
                    website_url: keyword_checking.website_url,
                    rank: rank || "Not found"
                  }
                end,
                max_concurrency: 10,
                timeout: :infinity
              )
              |> Enum.map(fn {:ok, result} -> result end)

            end_time = DateTime.utc_now()
            processing_time_ms = DateTime.diff(end_time, start_time, :millisecond)

            # Format processing time
            hours = div(processing_time_ms, 3600_000)
            rem_h = rem(processing_time_ms, 3600_000)
            minutes = div(rem_h, 60_000)
            rem_m = rem(rem_h, 60_000)
            seconds = div(rem_m, 1000)
            millis = rem(rem_m, 1000)
            tenth = div(millis, 100)

            processing_time = "#{pad(hours)}:#{pad(minutes)}:#{pad(seconds)}.#{tenth}"

            # Calculate stats
            total_keywords = length(results)

            ranked_count =
              Enum.count(results, fn r -> r.rank != nil and r.rank != "Not found" end)

            not_ranked_count = total_keywords - ranked_count

            # Generate XLSX file
            hcm_time = to_ho_chi_minh_time(DateTime.utc_now())
            timestamp_file = format_timestamp(hcm_time)
            timestamp_display = format_timestamp_display(hcm_time)

            {xlsx_content, _filename, _content_type} = generate_xlsx(results, timestamp_file)

            # Prepare report data
            report_data = %{
              total_keywords: total_keywords,
              ranked_count: ranked_count,
              not_ranked_count: not_ranked_count,
              processing_time: processing_time,
              timestamp: timestamp_file,
              timestamp_display: timestamp_display
            }

            # Send email
            result =
              case UserNotifier.deliver_keyword_ranking_report(user, report_data, xlsx_content) do
                {:ok, _email} ->
                  Logger.info("User #{user_id}: Keyword ranking report email sent successfully")

                  # Deduct tokens after successful email send
                  case Accounts.deduct_user_tokens(user, token_cost) do
                    {:ok, updated_user} ->
                      Logger.info(
                        "User #{user_id}: Deducted #{token_cost} tokens. Remaining: #{updated_user.token_amount}"
                      )

                      {:ok, :email_sent}

                    {:error, changeset} ->
                      Logger.error(
                        "User #{user_id}: Failed to deduct tokens - #{inspect(changeset)}"
                      )

                      # Still return success since email was sent
                      {:ok, :email_sent}
                  end

                {:error, reason} ->
                  Logger.error("User #{user_id}: Failed to send email - #{inspect(reason)}")
                  {:error, reason}
              end

            # Schedule next job for tomorrow at the same time
            schedule_next_job(user_id, hour, minute)

            result
          end
        end

      _ ->
        Logger.error("ScrapingDog API key not configured")
        {:error, :api_key_not_configured}
    end
  end

  defp schedule_next_job(user_id, hour, minute) do
    # Calculate next run time (tomorrow at the same hour:minute)
    now = DateTime.utc_now()
    hcm_now = to_ho_chi_minh_time(now)

    # Get tomorrow's date
    tomorrow = Date.add(DateTime.to_date(hcm_now), 1)

    # Create scheduled datetime for tomorrow
    {:ok, scheduled_naive} = NaiveDateTime.new(tomorrow, Time.new!(hour, minute, 0))
    {:ok, scheduled_hcm} = DateTime.from_naive(scheduled_naive, "Asia/Ho_Chi_Minh")

    # Schedule the job
    %{user_id: user_id, hour: hour, minute: minute}
    |> __MODULE__.new(scheduled_at: scheduled_hcm)
    |> Oban.insert()
    |> case do
      {:ok, _job} ->
        Logger.info(
          "User #{user_id}: Scheduled next keyword ranking email for #{Calendar.strftime(scheduled_hcm, "%d/%m/%Y %H:%M")}"
        )

        :ok

      {:error, changeset} ->
        Logger.error("User #{user_id}: Failed to schedule next job - #{inspect(changeset)}")
        :error
    end
  end

  defp pad(num) do
    num |> Integer.to_string() |> String.pad_leading(2, "0")
  end

  defp pad_zero(num) when num < 10, do: "0#{num}"
  defp pad_zero(num), do: num

  defp to_ho_chi_minh_time(datetime) do
    case DateTime.shift_zone(datetime, "Asia/Ho_Chi_Minh") do
      {:ok, converted_datetime} -> converted_datetime
      {:error, _} -> datetime
    end
  end

  defp format_timestamp(datetime) do
    "#{datetime.year}#{pad_zero(datetime.month)}#{pad_zero(datetime.day)}#{pad_zero(datetime.hour)}#{pad_zero(datetime.minute)}#{pad_zero(datetime.second)}"
  end

  defp format_timestamp_display(datetime) do
    Calendar.strftime(datetime, "%d/%m/%Y %H:%M")
  end

  defp generate_xlsx(results, timestamp) do
    filename = "keyword_ranking_report_#{timestamp}.xlsx"

    # Create workbook with Elixlsx
    sheet =
      results
      |> Enum.map(fn result ->
        [result.keyword, result.website_url, result.rank]
      end)
      |> then(fn rows -> [["Keyword", "Website URL", "Rank"] | rows] end)

    workbook = %Elixlsx.Workbook{
      sheets: [
        %Elixlsx.Sheet{
          name: "Results",
          rows: sheet
        }
      ]
    }

    {:ok, {_filename, content}} = Elixlsx.write_to_memory(workbook, filename)

    {content, filename, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"}
  end
end
