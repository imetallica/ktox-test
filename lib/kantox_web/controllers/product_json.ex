defmodule KantoxWeb.ProductJSON do
  alias Kantox.Products.Product

  def show(%{product: %Product{} = product}) do
    %{data: data(product)}
  end

  def data(%Product{} = product) do
    %{
      id: product.id,
      name: product.name,
      code: product.code,
      price: product.price,
      inserted_at: product.inserted_at
    }
  end
end
