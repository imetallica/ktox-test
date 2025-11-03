defmodule Kantox.CashierFixtures do
  @moduledoc false

  alias Kantox.Cashier
  alias Kantox.Cashier.ShoppingCart

  @doc """
  Creates an unpaid shopping cart using the domain API.
  """
  def shopping_cart_fixture(_attrs \\ %{}) do
    {:ok, %ShoppingCart{} = cart} = Cashier.create_shopping_cart()
    cart
  end

  @doc """
  Adds a product to the cart a number of times (default 1), returning the updated cart.
  """
  def add_item_fixture(cart, product, times \\ 1) when times >= 1 do
    Enum.reduce(1..times, cart, fn _, acc ->
      {:ok, cart} = Cashier.add_item_to_shopping_cart(acc, product)
      cart
    end)
  end
end
