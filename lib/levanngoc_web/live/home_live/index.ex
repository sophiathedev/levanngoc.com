defmodule LevanngocWeb.HomeLive.Index do
  use LevanngocWeb, :live_view

  import Ecto.Query

  # Tools configuration organized by category
  @tools %{
    keyword_research: [
      %{
        name: "Kiểm tra thứ hạng từ khóa",
        description: "Kiểm tra thứ hạng từ khóa của website trên Google search results",
        path: "/check-keyword-ranking",
        icon: "hero-chart-bar"
      },
      %{
        name: "Kiểm tra AllInTitle",
        description: "Phân tích độ cạnh tranh từ khóa với chỉ số AllInTitle",
        path: "/check-all-in-title",
        icon: "hero-document-magnifying-glass"
      },
      %{
        name: "Gom nhóm từ khóa",
        description: "Gom nhóm từ khóa thông minh dựa trên độ tương đồng ngữ nghĩa",
        path: "/keyword-grouping",
        icon: "hero-squares-2x2"
      },
      %{
        name: "Kiểm tra Keyword Cannibalization",
        description: "Phát hiện hiện tượng ăn thịt từ khóa giữa các trang trên website",
        path: "/check-keyword-cannibalization",
        icon: "hero-document-duplicate"
      }
    ],
    content_analysis: [
      %{
        name: "Kiểm tra nội dung trùng lặp",
        description: "Phát hiện nội dung trùng lặp giữa các trang web của bạn",
        path: "/check-duplicate-content",
        icon: "hero-document-check"
      },
      %{
        name: "Kiểm tra URL Index",
        description: "Kiểm tra tình trạng index của URL trên Google search engine",
        path: "/check-url-index",
        icon: "hero-globe-alt"
      }
    ],
    technical_seo: [
      %{
        name: "Tạo Schema Markup",
        description: "Tạo Schema.org markup chuẩn SEO cho website của bạn",
        path: "/schema-generator",
        icon: "hero-code-bracket"
      },
      %{
        name: "Kiểm tra Backlink",
        description: "Phân tích backlink và domain authority của website",
        path: "/backlink-checker",
        icon: "hero-link"
      },
      %{
        name: "Kiểm tra Redirect",
        description: "Kiểm tra chuỗi redirect và HTTP status code của URL",
        path: "/redirect-checker",
        icon: "hero-arrow-path"
      }
    ],
    utilities: [
      %{
        name: "Nén hình ảnh",
        description: "Nén và tối ưu hóa hình ảnh cho web với chất lượng cao",
        path: "/image-compression",
        icon: "hero-photo"
      },
      %{
        name: "Thêm Geo Tag",
        description: "Thêm thông tin địa lý vào metadata của hình ảnh",
        path: "/geo-tag",
        icon: "hero-map-pin"
      },
      %{
        name: "Gmail Alias Generator",
        description: "Tạo email alias Gmail số lượng lớn nhanh chóng",
        path: "/gmail-alias",
        icon: "hero-envelope"
      },
      %{
        name: "Robots.txt Generator",
        description: "Tạo file robots.txt chuẩn SEO cho website",
        path: "/robots-generator",
        icon: "hero-cog-6-tooth"
      },
      %{
        name: "Công cụ tiện ích khác",
        description: "Disavow Generator, Case Converter, Spinner Tool và nhiều hơn nữa",
        path: "/free-tools",
        icon: "hero-wrench-screwdriver"
      }
    ]
  }

  @category_names %{
    keyword_research: "Nghiên cứu từ khóa",
    content_analysis: "Phân tích nội dung",
    technical_seo: "SEO kỹ thuật",
    utilities: "Công cụ tiện ích"
  }

  # Quick access tools for logged-in users
  @quick_access_tools [
    %{
      name: "Kiểm tra thứ hạng từ khóa",
      path: "/check-keyword-ranking",
      icon: "hero-chart-bar"
    },
    %{
      name: "Gom nhóm từ khóa",
      path: "/keyword-grouping",
      icon: "hero-squares-2x2"
    },
    %{
      name: "Kiểm tra URL Index",
      path: "/check-url-index",
      icon: "hero-globe-alt"
    },
    %{
      name: "Kiểm tra Backlink",
      path: "/backlink-checker",
      icon: "hero-link"
    },
    %{
      name: "Nén hình ảnh",
      path: "/image-compression",
      icon: "hero-photo"
    },
    %{
      name: "Công cụ tiện ích",
      path: "/free-tools",
      icon: "hero-wrench-screwdriver"
    }
  ]

  @impl true
  def mount(_params, _session, socket) do
    # Get current subscription for logged-in user
    current_subscription =
      case socket.assigns[:current_scope] do
        %{user: %{id: user_id}} ->
          Levanngoc.Repo.one(
            from bh in Levanngoc.Billing.BillingHistory,
              where: bh.user_id == ^user_id and bh.is_current == true,
              preload: [:billing_price],
              limit: 1
          )

        _ ->
          nil
      end

    {:ok,
     socket
     |> assign(:page_title, "Công cụ SEO miễn phí")
     |> assign(:tools, @tools)
     |> assign(:category_names, @category_names)
     |> assign(:quick_access_tools, @quick_access_tools)
     |> assign(:current_subscription, current_subscription)
     |> load_recent_tools()}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    # Refresh recent tools every time we navigate back to homepage
    {:noreply, load_recent_tools(socket)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <%= if assigns[:current_scope] && assigns[:current_scope].user do %>
      {render_dashboard(assigns)}
    <% else %>
      {render_landing_page(assigns)}
    <% end %>
    """
  end

  # Helper function to format renewal date
  defp format_renewal_date(%DateTime{} = date) do
    Calendar.strftime(date, "%d/%m/%Y")
  end

  defp format_renewal_date(%NaiveDateTime{} = date) do
    Calendar.strftime(date, "%d/%m/%Y")
  end

  defp format_renewal_date(_), do: "Liên hệ hỗ trợ"

  # Helper function to load recent tools from cache
  defp load_recent_tools(socket) do
    recent_tools =
      case socket.assigns[:current_scope] do
        %{user: %{id: user_id}} ->
          cache_key = "recent_tools:#{user_id}"

          case Cachex.get(:cache, cache_key) do
            {:ok, nil} -> []
            {:ok, tools} when is_list(tools) -> tools
            _ -> []
          end

        _ ->
          []
      end

    assign(socket, :recent_tools, recent_tools)
  end

  # Dashboard for logged-in users
  defp render_dashboard(assigns) do
    ~H"""
    <!-- Welcome Section -->
    <section class="max-w-7xl mx-auto px-4 py-8 md:py-12">
      <div class="mb-8 flex items-start justify-between">
        <div>
          <h1 class="text-3xl md:text-4xl font-bold text-base-content mb-2">
            Xin chào, {@current_scope.user.email}
          </h1>
          <p class="text-base-content/60">
            Chào mừng trở lại! Sử dụng các công cụ SEO dưới đây để tối ưu website của bạn.
          </p>
        </div>
        <.link
          navigate={~p"/users/settings"}
          class="btn btn-outline btn-sm gap-2 flex-shrink-0"
        >
          <.icon name="hero-cog-6-tooth" class="size-4" /> Cài đặt
        </.link>
      </div>
      
    <!-- Stats Cards -->
      <div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-12">
        <!-- Token Balance -->
        <div class="card bg-gradient-to-br from-primary/10 to-primary/5 border border-primary/20">
          <div class="card-body flex justify-center">
            <div class="flex items-center gap-3">
              <div class="p-3 bg-primary/20 rounded-lg">
                <.icon name="hero-wallet" class="size-6 text-primary" />
              </div>
              <div>
                <p class="text-sm text-base-content/60">Token còn lại</p>
                <p class="text-2xl font-bold text-primary">
                  {(@current_scope.user.token_amount || 0)
                  |> trunc()
                  |> Number.Delimit.number_to_delimited(precision: 0)}
                </p>
              </div>
            </div>
          </div>
        </div>
        
    <!-- Subscription Plan -->
        <div class="card bg-base-200 border border-base-300">
          <div class="card-body flex items-center">
            <div class="flex items-center gap-3 w-full">
              <div class="p-3 bg-info/20 rounded-lg">
                <.icon name="hero-credit-card" class="size-6 text-info" />
              </div>
              <div class="flex-1">
                <p class="text-sm text-base-content/60">Gói đang sử dụng</p>
                <p class="text-lg font-semibold text-base-content">
                  <%= if @current_subscription && @current_subscription.billing_price do %>
                    {@current_subscription.billing_price.name}
                  <% else %>
                    Gói miễn phí
                  <% end %>
                </p>
                <%= if @current_subscription && @current_subscription.next_subscription_at do %>
                  <p class="text-xs text-base-content/50 mt-1">
                    Gia hạn: {format_renewal_date(@current_subscription.next_subscription_at)}
                  </p>
                <% end %>
              </div>
            </div>
          </div>
        </div>
      </div>
      
    <!-- Recent Tools (Công cụ thường dùng) -->
      <%= if length(@recent_tools) > 0 do %>
        <div class="mb-8">
          <h2 class="text-2xl font-bold text-base-content mb-6">Công cụ thường dùng</h2>

          <div class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-4">
            <%= for tool <- @recent_tools do %>
              <.link
                navigate={tool.path}
                class="group card bg-base-100 border border-base-300 hover:border-primary/50 hover:shadow-lg transition-all duration-200"
              >
                <div class="card-body items-center text-center p-6">
                  <.icon
                    name={tool.icon}
                    class="size-10 text-primary mb-3 group-hover:scale-110 transition-transform"
                  />
                  <h3 class="text-sm font-medium text-base-content leading-tight">
                    {tool.name}
                  </h3>
                </div>
              </.link>
            <% end %>
          </div>
        </div>
      <% end %>
      
    <!-- All Tools Section -->
      <div class="mb-8">
        <h2 class="text-2xl font-bold text-base-content mb-6">Tất cả công cụ</h2>

        <%= for {category_key, tools_list} <- @tools do %>
          <div class="mb-8 last:mb-0">
            <h3 class="text-lg font-semibold text-base-content mb-4 flex items-center gap-2">
              <span class="w-1 h-5 bg-primary rounded"></span>
              {@category_names[category_key]}
            </h3>
            <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
              <%= for tool <- tools_list do %>
                <.link
                  navigate={tool.path}
                  class="group flex items-start gap-3 p-4 bg-base-100 border border-base-300 rounded-lg hover:border-primary/50 hover:shadow-md transition-all duration-200"
                >
                  <.icon name={tool.icon} class="size-6 text-primary flex-shrink-0 mt-0.5" />
                  <div class="flex-1 min-w-0">
                    <h4 class="font-medium text-sm text-base-content mb-1 group-hover:text-primary transition-colors">
                      {tool.name}
                    </h4>
                    <p class="text-xs text-base-content/60 line-clamp-2">
                      {tool.description}
                    </p>
                  </div>
                </.link>
              <% end %>
            </div>
          </div>
        <% end %>
      </div>
    </section>
    """
  end

  # Landing page for non-logged-in users
  defp render_landing_page(assigns) do
    ~H"""
    <!-- Hero Section -->
    <section class="max-w-5xl mx-auto text-center py-16 px-4">
      <h1 class="text-4xl md:text-5xl lg:text-6xl font-bold mb-6 text-base-content">
        Bộ công cụ SEO miễn phí cho chuyên gia marketing
      </h1>
      <p class="text-lg md:text-xl text-base-content/70 mb-8 max-w-3xl mx-auto leading-relaxed">
        Phân tích, tối ưu và theo dõi hiệu suất SEO của bạn với 14+ công cụ chuyên nghiệp.
        Hoàn toàn miễn phí, không cần thẻ tín dụng.
      </p>
      <div class="flex gap-4 justify-center flex-wrap">
        <a href="#tools-section" class="btn btn-primary btn-lg">
          Khám phá công cụ
        </a>
        <.link navigate={~p"/users/register"} class="btn btn-outline btn-lg">
          Đăng ký ngay
        </.link>
      </div>
    </section>

    <!-- Tools Grid Section -->
    <section id="tools-section" class="max-w-7xl mx-auto px-4">
      <%= for {category_key, tools_list} <- @tools do %>
        <div class="mb-16 last:mb-0">
          <h2 class="text-2xl md:text-3xl font-bold mb-8 text-base-content">
            {@category_names[category_key]}
          </h2>
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            <%= for tool <- tools_list do %>
              <.link
                navigate={tool.path}
                class="group block bg-base-100 border border-base-300 rounded-lg p-6 hover:-translate-y-1 hover:shadow-lg transition-all duration-200"
              >
                <.icon name={tool.icon} class="size-10 text-primary mb-4" />
                <h3 class="font-semibold text-lg mb-2 text-base-content">
                  {tool.name}
                </h3>
                <p class="text-sm text-base-content/70 mb-4 leading-relaxed">
                  {tool.description}
                </p>
                <span class="text-primary text-sm font-medium group-hover:gap-2 inline-flex items-center gap-1 transition-all">
                  Thử ngay <.icon name="hero-arrow-right" class="size-4" />
                </span>
              </.link>
            <% end %>
          </div>
        </div>
      <% end %>
    </section>

    <!-- Footer Section -->
    <footer class="border-t border-base-300 mt-16 py-8 px-4">
      <div class="max-w-7xl mx-auto text-center">
        <div class="flex gap-4 justify-center items-center flex-wrap text-sm text-base-content/60">
          <.link
            navigate={~p"/privacy-policy"}
            class="link link-hover hover:text-primary transition-colors"
          >
            Chính sách bảo mật
          </.link>
          <span class="text-base-content/30">•</span>
          <.link
            navigate={~p"/refund-policy"}
            class="link link-hover hover:text-primary transition-colors"
          >
            Chính sách hoàn tiền
          </.link>
          <span class="text-base-content/30">•</span>
          <.link
            navigate={~p"/terms-of-service"}
            class="link link-hover hover:text-primary transition-colors"
          >
            Điều khoản sử dụng
          </.link>
        </div>
        <p class="mt-4 text-sm text-base-content/50">
          © {DateTime.utc_now().year} Levanngoc.com - Công cụ SEO miễn phí
        </p>
      </div>
    </footer>
    """
  end
end
