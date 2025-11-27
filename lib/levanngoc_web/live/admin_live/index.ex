defmodule LevanngocWeb.AdminLive.Index do
  use LevanngocWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <div>
        <h1 class="text-3xl font-bold">Chào mừng đến với Bảng điều khiển Quản trị</h1>
        <p class="text-neutral-content mt-2">Quản lý ứng dụng của bạn từ đây</p>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        <div class="stats shadow">
          <div class="stat">
            <div class="stat-title">Tổng số người dùng</div>
            <div class="stat-value">0</div>
            <div class="stat-desc">Tất cả người dùng đã đăng ký</div>
          </div>
        </div>

        <div class="stats shadow">
          <div class="stat">
            <div class="stat-title">Phiên hoạt động</div>
            <div class="stat-value">1</div>
            <div class="stat-desc">Hiện đang đăng nhập</div>
          </div>
        </div>

        <div class="stats shadow">
          <div class="stat">
            <div class="stat-title">Vai trò của bạn</div>
            <div class="stat-value text-primary">Superuser</div>
            <div class="stat-desc">{@current_scope.user.email}</div>
          </div>
        </div>
      </div>

      <div class="card bg-base-200">
        <div class="card-body">
          <h2 class="card-title">Hành động nhanh</h2>
          <div class="flex flex-wrap gap-2 mt-4">
            <.link class="btn btn-primary" href={~p"/admin/users"}>Quản lý người dùng</.link>
            <button class="btn btn-secondary">Xem báo cáo</button>
            <button class="btn btn-accent">Cài đặt hệ thống</button>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
