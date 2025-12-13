defmodule Levanngoc.External.Spintax do
  @moduledoc """
  Module for handling spintax format text processing.
  """

  @doc """
  Recursively unspins text with spintax format {option1|option2|option3}.
  Randomly selects one option from each group.

  ## Examples

      iex> Levanngoc.External.Spintax.unspin("Hello World")
      "Hello World"

      iex> text = "{Hello|Hi} {World|Everyone}"
      iex> result = Levanngoc.External.Spintax.unspin(text)
      iex> result in ["Hello World", "Hello Everyone", "Hi World", "Hi Everyone"]
      true
  """
  def unspin(text) when is_binary(text) do
    # 1. Regex tìm các cụm {...} nằm trong cùng nhất (không chứa ngoặc nhọn khác bên trong)
    # \{ : Tìm dấu mở ngoặc nhọn
    # ([^{}]+) : Group bắt buộc nội dung bên trong, KHÔNG được chứa { hoặc }
    # \} : Tìm dấu đóng ngoặc nhọn
    regex = ~r/\{([^{}]+)\}/

    if Regex.match?(regex, text) do
      # 2. Thay thế tất cả các cụm tìm được
      new_text =
        Regex.replace(regex, text, fn _whole_match, content ->
          content
          # Tách các lựa chọn bằng dấu gạch đứng
          |> String.split("|")
          # Chọn ngẫu nhiên 1 cái
          |> Enum.random()
        end)

      # 3. Gọi đệ quy lại chính hàm này để xử lý các lớp ngoặc bên ngoài (nếu còn)
      unspin(new_text)
    else
      # 4. Nếu không còn dấu ngoặc nào khớp regex, trả về kết quả cuối cùng
      text
    end
  end

  @doc """
  Converts nested spintax to 1-level spin format.
  Generates all possible variations and combines them into a single spin group.

  ## Examples

      iex> Levanngoc.External.Spintax.to_one_level("{A|B} {C|D}")
      "{A C|A D|B C|B D}"

      iex> Levanngoc.External.Spintax.to_one_level("Hello World")
      "{Hello World}"
  """
  def to_one_level(text) do
    # 1. Tạo ra tất cả các biến thể (Permutations)
    variations = generate_permutations(text)

    # 2. Loại bỏ trùng lặp (nếu có)
    unique_variations = Enum.uniq(variations)

    # 3. Gộp lại thành chuỗi 1-Level Spin
    "{" <> Enum.join(unique_variations, "|") <> "}"
  end

  # Hàm đệ quy cốt lõi để tạo ra các biến thể
  defp generate_permutations(text) do
    # Regex tìm cụm ngoặc nhọn nằm trong cùng (không chứa ngoặc khác bên trong)
    # Group 1: Nội dung bên trong ngoặc
    regex = ~r/\{([^{}]+)\}/

    case Regex.run(regex, text, return: :index) do
      nil ->
        # ĐIỀU KIỆN DỪNG: Nếu không còn dấu ngoặc nào, trả về chính nó trong list
        [text]

      [{start, len}, {content_start, content_len}] ->
        # 1. Cắt chuỗi thành 3 phần: Trước ngoặc, Nội dung trong ngoặc, Sau ngoặc
        prefix = String.slice(text, 0, start)
        suffix = String.slice(text, start + len, String.length(text))
        content = String.slice(text, content_start, content_len)

        # 2. Tách nội dung trong ngoặc thành các lựa chọn (options)
        options = String.split(content, "|")

        # 3. Với mỗi option, tạo ra một chuỗi mới tạm thời và tiếp tục đệ quy
        # Ví dụ: từ "A {B|C}" tạo ra ["A B", "A C"] rồi tiếp tục xử lý từng cái
        options
        |> Enum.flat_map(fn option ->
          new_text_segment = prefix <> option <> suffix
          generate_permutations(new_text_segment)
        end)
    end
  end

  @doc """
  Converts Unique Article Wizard format to standard HTML.
  - Converts [spin]A|B[/spin] to {A|B}
  - Converts [url=https://site.com]keyword[/url] to <a href="https://site.com">keyword</a>

  ## Examples

      iex> Levanngoc.External.Spintax.convert("[spin]A|B[/spin]")
      "{A|B}"

      iex> Levanngoc.External.Spintax.convert("[url=https://google.com]Google[/url]")
      ~s(<a href="https://google.com">Google</a>)
  """
  def convert(text) do
    text
    # Bước 1: Chuyển đổi cú pháp spin lạ (ví dụ [spin]A|B[/spin]) về chuẩn {A|B}
    |> String.replace("[spin]", "{")
    |> String.replace("[/spin]", "}")
    # Bước 2: Chuyển đổi Link từ BBCode sang HTML
    # Input: [url=https://site.com]keyword[/url]
    # Output: <a href="https://site.com">keyword</a>
    |> convert_bbcode_links()
  end

  defp convert_bbcode_links(text) do
    # Regex bắt cụm [url=...]...[/url]
    # Group 1: URL
    # Group 2: Anchor Text
    Regex.replace(~r/\[url=(.*?)\](.*?)\[\/url\]/, text, fn _, url, anchor ->
      "<a href=\"#{url}\">#{anchor}</a>"
    end)
  end

  @doc """
  Converts HTML links to BBCode format for SEO Link Vine.
  - Converts <a href="https://site.com">keyword</a> to [url=https://site.com]keyword[/url]

  ## Examples

      iex> Levanngoc.External.Spintax.convert_to_bbcode(~s(<a href="https://google.com">Google</a>))
      "[url=https://google.com]Google[/url]"
  """
  def convert_to_bbcode(text) do
    # Regex giải thích:
    # <a\s+ : Tìm thẻ mở <a có khoảng trắng
    # (?:[^>]*?\s+)? : (Non-capturing group) Bỏ qua các thuộc tính khác nếu có (như class, id...) trước href
    # href=["'](.*?)["'] : Group 1 - Bắt lấy URL bên trong dấu nháy đơn hoặc kép
    # [^>]*> : Bỏ qua các thuộc tính còn lại cho đến khi đóng thẻ >
    # (.*?) : Group 2 - Bắt lấy Anchor Text
    # <\/a> : Thẻ đóng
    regex = ~r/<a\s+(?:[^>]*?\s+)?href=["'](.*?)["'][^>]*>(.*?)<\/a>/i

    Regex.replace(regex, text, fn _, url, anchor ->
      "[url=#{url}]#{anchor}[/url]"
    end)
  end

  @doc """
  Processes text for Free Traffic System format.
  - Cleans special characters from Word (smart quotes)
  - Normalizes spintax [spin] to {}
  - Converts BBCode [url] to HTML <a href>
  - Converts newlines to <br /> tags

  ## Examples

      iex> Levanngoc.External.Spintax.convert_to_fts("[spin]A|B[/spin]\\n[url=https://google.com]Google[/url]")
      "{A|B}<br /><a href=\\"https://google.com\\">Google</a>"
  """
  def convert_to_fts(text) do
    text
    # 1. Vệ sinh ký tự đặc biệt từ Word (Smart Quotes) gây lỗi hệ thống cũ
    # Ngoặc đơn cong -> thẳng
    |> String.replace(~r/[\x{2018}\x{2019}]/u, "'")
    # Ngoặc kép cong -> thẳng
    |> String.replace(~r/[\x{201C}\x{201D}]/u, "\"")
    # Dấu ba chấm
    |> String.replace(~r/\x{2026}/u, "...")
    # Dấu gạch ngang
    |> String.replace(~r/\x{2013}/u, "-")
    # 2. Chuẩn hóa Spintax (Chuyển [spin] thành { })
    |> String.replace("[spin]", "{")
    |> String.replace("[/spin]", "}")
    # 3. Chuyển đổi BBCode [url] sang HTML <a href>
    # Regex bắt: [url=LINK]TEXT[/url] (không phân biệt hoa thường)
    |> then(fn t ->
      Regex.replace(~r/\[url=(.*?)\](.*?)\[\/url\]/i, t, fn _, url, anchor ->
        "<a href=\"#{url}\">#{anchor}</a>"
      end)
    end)
    # 4. Xử lý xuống dòng: FTS cần thẻ <br /> thay vì \n đơn thuần
    |> String.replace(~r/\r?\n/, "<br />")
  end

  @doc """
  Processes text for Article Rank (2 levels) format.
  - Cleans special characters from Word (smart quotes)
  - Normalizes spintax [spin] to {}
  - Converts BBCode [url] to HTML <a href>
  - Converts newlines to <br /> tags

  ## Examples

      iex> Levanngoc.External.Spintax.convert_to_article_rank("[spin]A|B[/spin]\\n[url=https://google.com]Google[/url]")
      "{A|B}<br /><a href=\\"https://google.com\\">Google</a>"
  """
  def convert_to_article_rank(text) do
    text
    # 1. Vệ sinh ký tự từ Word (Smart Quotes) - Bước chuẩn bắt buộc cho mọi tool SEO cũ
    |> String.replace(~r/[\x{2018}\x{2019}]/u, "'")
    |> String.replace(~r/[\x{201C}\x{201D}]/u, "\"")
    |> String.replace(~r/\x{2026}/u, "...")
    |> String.replace(~r/\x{2013}/u, "-")
    # 2. Chuẩn hóa Spintax (Nếu user dùng [spin] kiểu cũ thì đổi về { })
    |> String.replace("[spin]", "{")
    |> String.replace("[/spin]", "}")
    # 3. Chuyển đổi BBCode [url] thành HTML <a href> (ArticleRanks dùng HTML)
    |> convert_bbcode_to_html()
    # 4. Định dạng xuống dòng (ArticleRanks thường thích HTML break line)
    |> String.replace(~r/\r?\n/, "<br />")
  end

  # Hàm phụ trợ convert link
  defp convert_bbcode_to_html(text) do
    Regex.replace(~r/\[url=(.*?)\](.*?)\[\/url\]/i, text, fn _, url, anchor ->
      "<a href=\"#{url}\">#{anchor}</a>"
    end)
  end
end
