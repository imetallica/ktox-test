defmodule Kantox.Products do
  @moduledoc false

  alias Kantox.Products.Product
  alias Kantox.Repo

  @spec list_products() :: [Product.t(), ...] | []
  def list_products do
    Repo.all(Product)
  end

  @spec get_product_by_id(id :: Ecto.UUID.t()) :: Product.t() | nil
  def get_product_by_id(id) when is_binary(id) do
    Repo.get(Product, id)
  end
end
