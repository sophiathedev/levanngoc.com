#!/bin/bash

# Dừng chạy ngay lập tức nếu có bất kỳ lệnh nào lỗi
set -e

# Hàm in ra thông báo lỗi khi script bị dừng
handle_error() {
    local exit_code=$?
    echo "❌ Đã có lỗi xảy ra (Exit code: $exit_code)"
    echo "Lệnh bị lỗi: $BASH_COMMAND"
    echo "Dừng script ngay lập tức."
}

# Bắt sự kiện lỗi (ERR) và gọi hàm handle_error
trap handle_error ERR

echo "🚀 Bắt đầu quá trình deploy..."

echo "----------------------------------------"
echo "1. Dừng process 'levanngoc' đang chạy..."
pkill -f levanngoc || true

echo "2. Cập nhật code từ git..."
git pull origin

echo "3. Xóa các thư mục build cũ và log..."
rm -rf _build deps rel production.log

echo "4. Cài đặt dependencies và build release..."
mix deps.get --only prod && \
MIX_ENV=prod mix compile && \
MIX_ENV=prod mix assets.deploy && \
MIX_ENV=prod mix phx.gen.release && \
MIX_ENV=prod mix release

echo "5. Load biến môi trường..."
source .env

echo "6. Khởi động server dưới dạng daemon..."
_build/prod/rel/levanngoc/bin/levanngoc daemon

echo "----------------------------------------"
echo "✅ Deploy thành công!"
