defmodule Manga do
  use Application

  import Manga.Utils.Printer
  import Manga.Utils.ProgressBar
  alias Manga.Utils.Props
  use Tabula, style: :github_md

  @moduledoc """
  Documentation for Manga.
  """

  @doc """
  Hello world.

  ## Examples

      iex> Manga.hello
      :world

  """
  def hello do
    :world
  end

  use Manga.Res, :models
  alias Manga.Utils.IOUtils

  @version "alpha9-2"

  @platforms [
    dmzj:
      Platform.create(
        name: "动漫之家",
        origin: Manga.Res.DMZJOrigin,
        url: "https://manhua.dmzj.com"
      ),
    fzdm:
      Platform.create(
        name: "风之动漫",
        origin: Manga.Res.FZDMOrigin,
        url: "https://www.fzdm.com"
      ),
    dmk:
      Platform.create(
        name: "動漫狂",
        origin: Manga.Res.DMKOrigin,
        url: "http://www.cartoonmad.com"
      ),
    mhg:
      Platform.create(
        name: "漫画柜",
        origin: Manga.Res.MHGOrigin,
        url: "https://www.manhuagui.com"
      ),
    dm5:
      Platform.create(
        name: "动漫屋",
        origin: Manga.Res.DM5Origin,
        url: "http://www.dm5.com/"
      )
  ]

  def main(args \\ []) do
    switches = [
      version: :boolean,
      help: :boolean,
      delay: :lists
    ]

    aliases = [
      v: :version,
      h: :help,
      d: :delay
    ]

    parsed = OptionParser.parse(args, switches: switches, aliases: aliases)
    # IO.inspect(parsed)

    case parsed do
      {_, ["cleancache"], _} ->
        File.rm_rf("./_res/.cache")

      {[version: true], _, _} ->
        print_normal("Erlang/OPT #{:erlang.system_info(:otp_release)} [#{get_system_info()}]")
        print_normal("Manga.ex #{@version}")

      {props, argv, _} ->
        Props.set_delay(props[:delay])

        if length(argv) > 0 do
          url =
            argv
            |> List.first()

          action(:intellig, url: url)
        else
          action(:default)
        end
    end
  end

  def action(:default) do
    # 交互模式
    print_normal("Welcome to Manga.ex! Currently supported platform list:\n")

    list =
      @platforms
      |> Enum.map(fn {_, platform} -> platform end)
      |> Enum.with_index()
      |> Enum.map(fn {platform, i} ->
        print_result(
          "[#{i + 1}]: #{platform.name}#{
            if platform.flags == nil, do: "", else: "(#{platform.flags})"
          }"
        )

        platform
      end)

    {n, _} =
      IOUtils.gets("\nPlease select a platform, [Number]: ")
      |> String.trim()
      |> Integer.parse()

    origin = Enum.at(list, n - 1)
    Props.init_more(origin)
    index(origin)
  end

  def action(:intellig, url: url) do
    export(url)
  end

  defp index(p) do
    case p.origin.index(Props.get_and_more()) do
      {:ok, list} ->
        newline()

        list
        |> Enum.with_index()
        |> Enum.each(fn {manga_info, i} ->
          print_result("[#{i + 1}]: #{manga_info.name}")
        end)

        case IOUtils.gets_number("\n[Number -> select a manga] or [Anything -> next page]: ") do
          {n, _} -> Enum.at(list, n - 1).url |> export()
          :error -> index(p)
        end

      {:error, error} ->
        print_error(error)
    end
  end

  defp export(url) do
    case platform?(url) do
      # 待选择的(话/卷)列表
      {:stages, key} ->
        newline()

        case @platforms[key].origin.stages(Info.create(url: url)) do
          {:ok, manga_info} ->
            list =
              manga_info.stage_list
              |> Enum.with_index()
              |> Enum.map(fn {stage, i} ->
                print_result("[#{i + 1}]: #{stage.name}")
                stage
              end)

            IOUtils.gets_numbers("\nPlease select a stage, [n/n1,n2/n1-n5,n7]: ")
            |> Enum.each(fn n -> Enum.at(list, n - 1).url |> export() end)

          {:error, error} ->
            print_error(error)
        end

      # 获取漫画内容（下载并保存）
      {:fetch, key} ->
        with {:ok, stage} <- @platforms[key].origin.fetch(Stage.create(url: url)),
             {:ok, _} <- Manga.Utils.Downloader.from_stage(stage),
             rlist <-
               (fn ->
                  stage = Stage.set_platform(stage, @platforms[key])
                  converter_list = get_converter_list()
                  render_length = length(converter_list)
                  render_export(stage.name, 0, render_length)

                  converter_list
                  |> Enum.with_index()
                  |> Enum.map(fn {{format, converter}, i} ->
                    r = converter.save_from_stage(stage)
                    render_export(stage.name, i + 1, render_length)
                    {format, r}
                  end)
                end).() do
          newline()
          # 输出结果

          rlist
          |> Enum.map(fn r ->
            case r do
              {format, {:ok, path}} ->
                %{"FORMAT" => format, "PATH" => path, "RESULT" => "✔"}

              {format, {:error, error}} ->
                %{"FORMAT" => format, "ERROR" => error, "RESULT" => "✘"}
            end
          end)
          |> print_table
        else
          {:error, error} ->
            print_error(error)
        end

      {:error, error} ->
        print_error(error)
    end
  end

  @url_mapping [
    [
      pattern: ~r/https?:\/\/manhua\.fzdm\.com\/\d+\/$/i,
      type: {:stages, :fzdm}
    ],
    [
      pattern: ~r/https?:\/\/manhua\.fzdm\.com\/\d+\/[^\/]+\//i,
      type: {:fetch, :fzdm}
    ],
    [
      pattern: ~r/https?:\/\/manhua\.dmzj\.com\/[^\/]+\/?$/i,
      type: {:stages, :dmzj}
    ],
    [
      pattern: ~r/https?:\/\/manhua\.dmzj\.com\/[^\/]+\/\d+\.shtml/i,
      type: {:fetch, :dmzj}
    ],
    [
      pattern: ~r/https?:\/\/www\.dm5\.com\/m\d{6,}[^\/]*\/?$/i,
      type: {:fetch, :dm5}
    ],
    [
      pattern: ~r/https?:\/\/www\.dm5\.com\/[^\/]+\/?$/i,
      type: {:stages, :dm5}
    ],
    [
      pattern: ~r{https?://www\.manhuagui\.com/comic/\d+/?$}i,
      type: {:stages, :mhg}
    ]
  ]

  defp platform?(url) do
    is_match = fn pattern -> Regex.match?(pattern, url) end

    @url_mapping
    |> Enum.filter(fn mapping ->
      is_match.(mapping[:pattern])
    end)
    |> List.first()
    |> (fn mapping ->
          if mapping == nil, do: {:error, "Unknown platform url"}, else: mapping[:type]
        end).()
  end

  defp get_system_info do
    {family, name} = :os.type()
    "#{Atom.to_string(family)}/#{Atom.to_string(name)}"
  end

  defp get_converter_list do
    [{"EPUB", Manga.Res.EpubExport}, {"MOBI", Manga.Res.MobiExport}, {"PDF", Manga.Res.PdfExport}]
  end

  def start(_type, _args) do
    Props.start_link(%{})
  end
end
