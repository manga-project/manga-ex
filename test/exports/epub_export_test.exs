defmodule Manga.Res.EpubExportTest do
  use ExUnit.Case
  import Manga.Res.EpubExport
  alias Manga.DLUtils
  import Manga.Res.FZDMOrigin

  test "save_from_stage" do
    # 拉取资源
    {state, r} =
      fetch(%Manga.Res.Stage{
        name: "灵能百分百101话",
        url: "https://manhua.fzdm.com/49/101/"
      })

    send(self(), state)
    assert_received :ok, r
    # 下载资源
    DLUtils.from_stage(r)
    # 合并资源
    {state, _} = save_from_stage(r)
    assert state == :ok
  end
end