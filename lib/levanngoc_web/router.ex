defmodule LevanngocWeb.Router do
  use LevanngocWeb, :router

  import LevanngocWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {LevanngocWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", LevanngocWeb do
    pipe_through :browser

    live_session :app,
      layout: {LevanngocWeb.Layouts, :app},
      on_mount: [{LevanngocWeb.UserAuth, :mount_current_scope}] do
      live "/", HomeLive.Index, :index
      live "/check_url_index", CheckUrlIndexLive.Index, :index
      live "/check_all_in_title", CheckAllInTitleLive.Index, :index
      live "/check_keyword_ranking", CheckKeywordRankingLive.Index, :index
      live "/keyword_grouping", KeywordGroupingLive.Index, :index
      live "/check_duplicate_content", CheckDuplicateContentLive.Index, :index
    end
  end

  scope "/", LevanngocWeb do
    pipe_through :api

    post "/payment/success", PaymentController, :received_success_payment
  end

  # Other scopes may use custom stacks.
  # scope "/api", LevanngocWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:levanngoc, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: LevanngocWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", LevanngocWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      layout: {LevanngocWeb.Layouts, :app},
      on_mount: [{LevanngocWeb.UserAuth, :require_authenticated}] do
      live "/users/settings", UserLive.Settings, :edit
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
      live "/users/billing", UserLive.Billing, :index
    end

    post "/users/update-password", UserSessionController, :update_password
  end

  ## Admin routes (superuser only)

  scope "/", LevanngocWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_superuser,
      layout: {LevanngocWeb.Layouts, :admin},
      on_mount: [{LevanngocWeb.UserAuth, :require_superuser}] do
      live "/admin", AdminLive.Index, :index
      live "/admin/api", AdminLive.Api, :index
      live "/admin/token-usage", AdminLive.TokenUsage, :index
      live "/admin/users", AdminLive.UserManagement, :index
      live "/admin/pricing", AdminLive.Pricing, :index
      live "/admin/email-templates", AdminLive.EmailManagement, :index
      live "/admin/email-templates/:template_id", AdminLive.EmailManagement, :edit
    end
  end

  scope "/", LevanngocWeb do
    pipe_through [:browser]

    live_session :current_user,
      layout: {LevanngocWeb.Layouts, :app},
      on_mount: [{LevanngocWeb.UserAuth, :mount_current_scope}] do
      live "/users/register", UserLive.Registration, :new
      live "/users/log-in", UserLive.Login, :new
      live "/users/log-in/:token", UserLive.Confirmation, :new
      live "/users/forgot-password", UserLive.ForgotPassword, :new
    end

    # Reset password - no layout
    live_session :reset_password,
      layout: false,
      on_mount: [{LevanngocWeb.UserAuth, :mount_current_scope}] do
      live "/users/reset-password/:token", UserLive.ResetPassword, :new
    end

    # Account activation - no layout
    live_session :activation,
      layout: false,
      on_mount: [{LevanngocWeb.UserAuth, :mount_current_scope}] do
      live "/users/activation", UserLive.Activation, :new
    end



    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end
end
