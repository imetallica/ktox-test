defmodule KantoxWeb.ShoppingCartItemJSON do
  alias Kantox.Cashier.ShoppingCartItem
  alias KantoxWeb.ProductJSON

  @spec index(%{shopping_cart_items: [ShoppingCartItem.t(), ...] | []}) :: map()
  def index(%{shopping_cart_items: shopping_cart_items}) do
    %{data: for(item <- shopping_cart_items, do: data(item))}
  end

  @spec data(shopping_cart_item :: ShoppingCartItem.t()) :: map()
  def data(%ShoppingCartItem{} = item) do
    %{
      id: item.id,
      quantity: item.quantity,
      total_price: item.total_price,
      discount_amount: item.discount_amount,
      final_price: Decimal.sub(item.total_price, item.discount_amount),
      product: ProductJSON.data(item.product),
      inserted_at: item.inserted_at
    }
  end
end
