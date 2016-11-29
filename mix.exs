defmodule EXSD.Mixfile do
  use Mix.Project

  def project do
    [app: :exsd,
     version: "0.1.0",
     elixir: "~> 1.3",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     consolidate_protocols: Mix.env == :prod,
     deps: deps()]
  end

  def application do
    [applications: [
      :erlsom,
      :logger
    ]]
  end

  defp deps do
    [{:erlsom, "~> 1.4"},
     {:multix, github: "camshaft/multix"},
     {:mix_test_watch, ">= 0.0.0", only: [:dev]}]
  end
end
