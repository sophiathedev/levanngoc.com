defmodule LevanngocWeb.HomeLive.Index do
  use LevanngocWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto">
      <div class="hero py-8">
        <div class="hero-content text-center">
          <div class="max-w-2xl">
            <h1 class="text-5xl font-bold mb-6">Chào mừng đến với levanngoc.com</h1>
            <p class="py-6 text-lg">
              Nền tảng cung cấp các dịch vụ công nghệ và giải pháp số hóa chuyên nghiệp.
            </p>
            <div class="flex gap-4 justify-center">
              <.link href="/services" class="btn btn-primary">
                Khám phá dịch vụ
              </.link>
              <.link href="/about" class="btn btn-outline">
                Tìm hiểu thêm
              </.link>
            </div>
          </div>
        </div>
      </div>

      <div class="divider"></div>

      <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mt-8">
        <div class="card bg-base-200">
          <div class="card-body">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="h-12 w-12 mb-4 text-primary"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M13 10V3L4 14h7v7l9-11h-7z"
              />
            </svg>
            <h2 class="card-title">Nhanh chóng</h2>
            <p>Triển khai và vận hành dịch vụ với tốc độ cao.</p>
          </div>
        </div>

        <div class="card bg-base-200">
          <div class="card-body">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="h-12 w-12 mb-4 text-primary"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z"
              />
            </svg>
            <h2 class="card-title">Bảo mật</h2>
            <p>Đảm bảo an toàn dữ liệu và quyền riêng tư.</p>
          </div>
        </div>

        <div class="card bg-base-200">
          <div class="card-body">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="h-12 w-12 mb-4 text-primary"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M12 6V4m0 2a2 2 0 100 4m0-4a2 2 0 110 4m-6 8a2 2 0 100-4m0 4a2 2 0 110-4m0 4v2m0-6V4m6 6v10m6-2a2 2 0 100-4m0 4a2 2 0 110-4m0 4v2m0-6V4"
              />
            </svg>
            <h2 class="card-title">Linh hoạt</h2>
            <p>Tuỳ chỉnh theo nhu cầu cụ thể của bạn.</p>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
