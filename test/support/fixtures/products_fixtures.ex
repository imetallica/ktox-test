defmodule Kantox.ProductsFixtures do
  @moduledoc false

  alias Kantox.Products.Product
  alias Kantox.Repo

  @doc """
  Creates and inserts a product for tests.

  Accepts optional attrs to override defaults.
  """
  def product_fixture(attrs \\ %{}) do
    defaults = %{
      name: "Product #{System.unique_integer([:positive])}",
      code: "CODE-#{System.unique_integer([:positive])}",
      price: Decimal.new("3.50")
    }

    attrs = Map.merge(defaults, attrs)

    %Product{}
    |> Product.changeset(attrs)
    |> Repo.insert!()
  end
end
