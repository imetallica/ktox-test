defmodule KantoxWeb.ShoppingCartJSON do
  alias Kantox.Cashier.ShoppingCart
  alias KantoxWeb.ShoppingCartItemJSON

  @spec index(%{shopping_carts: [ShoppingCart.t(), ...] | []}) :: map()
  def index(%{shopping_carts: shopping_carts}) do
    %{data: for(cart <- shopping_carts, do: data(cart))}
  end

  @spec show(%{shopping_cart: ShoppingCart.t() | nil}) :: map()
  def show(%{shopping_cart: shopping_cart}) do
    if is_nil(shopping_cart) do
      %{data: nil}
    else
      %{data: data(shopping_cart)}
    end
  end

  @spec data(shopping_cart :: ShoppingCart.t()) :: map()
  def data(%ShoppingCart{} = cart) do
    %{
      id: cart.id,
      status: cart.status,
      items: for(item <- cart.items, do: ShoppingCartItemJSON.data(item)),
      inserted_at: cart.inserted_at
    }
  end
end
