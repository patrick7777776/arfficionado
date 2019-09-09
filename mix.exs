defmodule Arfficionado.MixProject do
  use Mix.Project

  def project do
    [
      app: :arfficionado,
      version: "0.1.0",
      elixir: "~> 1.8",
      description: description(),
      package: package(),
      source_url: "https://github.com/patrick7777776/arfficionado",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.21", only: :dev, runtime: false}
    ]
  end

  defp description() do
    "Arfficionado: reader for ARFF data sets (Attribute Relation File Format)."
  end

  defp package() do
    [
      name: "arfficionado",
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => "https://github.com/patrick7777776/arfficionado"}
    ]
  end

end
