defmodule Manga.PrintUtils do
  def print_info(text) do
    "#{IO.ANSI.color(8)}#{text}" |> IO.puts()
  end

  def print_result(text) do
    "#{IO.ANSI.blue()}#{text}" |> IO.puts()
  end

  def print_error(error) do
    "#{IO.ANSI.red()}[Error] #{error}\n" |> (&IO.write(:stderr, &1)).()
  end
end