defmodule EXSD do
  defmacro __using__(_) do
    quote do
      use EXSD.Compiler
    end
  end

  def parse!(url, xml) do
    module = EXSD.Locator.locate(url)
    module.parse!(xml)
  end

  def parse(url, xml) do
    case locate(url) do
      nil ->
        {:error, :invalid_url}
      module ->
        module.parse(xml)
    end
  end

  def locate(url) do
    EXSD.Locator.locate(url)
  rescue
    _ ->
      nil
  end
end
