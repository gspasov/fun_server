defmodule FunServer.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/gspasov/fun_server"

  def project do
    [
      app: :fun_server,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "FunServer",
      description: "A way of writing GenServer using function handlers instead of callbacks",
      source_url: @source_url,
      package: package(),
      docs: docs()
    ]
  end

  defp docs do
    [
      source_ref: "v#{@version}",
      main: "overview",
      formatters: ["html"],
      extras: extras()
    ]
  end

  defp extras do
    [
      "README.md": [title: "Overview"],
      LICENSE: [title: "License"]
    ]
  end

  defp package do
    [
      files: [
        "lib",
        "LICENSE",
        "mix.exs",
        "README.md"
      ],
      maintainers: ["Georgi Spasov"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url
      }
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: :dev, runtime: false}
    ]
  end
end
