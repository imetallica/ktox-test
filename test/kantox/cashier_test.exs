defmodule Kantox.CashierTest do
  use Kantox.DataCase, async: true

  import Kantox.CashierFixtures
  import Kantox.ProductsFixtures

  alias Kantox.Cashier
  alias Kantox.Cashier.ShoppingCart
  alias Kantox.Cashier.ShoppingCartItem
  alias Kantox.Repo

  describe "create_shopping_cart/0" do
    test "inserts and returns an unpaid shopping cart" do
      assert {:ok, %ShoppingCart{} = cart} = Cashier.create_shopping_cart()

      assert cart.status == :unpaid
      assert is_binary(cart.id)

      # persisted in DB
      persisted = Repo.get!(ShoppingCart, cart.id)
      assert persisted.status == :unpaid

      # initially no items
      persisted = Repo.preload(persisted, :items)
      assert persisted.items == []
    end
  end

  describe "add_item_to_shopping_cart/2" do
    setup do
      cart = shopping_cart_fixture()
      product = product_fixture(%{name: "Tea", code: "TEA", price: Decimal.new("3.50")})
      %{cart: cart, product: product}
    end

    test "creates a new item when product is not yet in the cart", %{cart: cart, product: product} do
      assert {:ok, %ShoppingCart{} = updated} = Cashier.add_item_to_shopping_cart(cart, product)

      updated = Repo.preload(updated, :items)
      assert length(updated.items) == 1

      [%ShoppingCartItem{} = item] = updated.items
      assert item.quantity == 1
      assert Decimal.eq?(item.total_price, product.price)

      # persisted and unique per cart-product
      item_db = Repo.get!(ShoppingCartItem, item.id)
      assert item_db.quantity == 1
      assert Decimal.eq?(item_db.total_price, product.price)
    end

    test "increments quantity and price when product is already in the cart", %{cart: cart, product: product} do
      assert {:ok, %ShoppingCart{} = cart} = Cashier.add_item_to_shopping_cart(cart, product)
      assert {:ok, %ShoppingCart{} = cart} = Cashier.add_item_to_shopping_cart(cart, product)

      cart = Repo.preload(cart, :items)
      assert length(cart.items) == 1

      [%ShoppingCartItem{} = item] = cart.items
      assert item.quantity == 2
      assert Decimal.eq?(item.total_price, Decimal.mult(product.price, 2))
    end
  end

  describe "remove_item_from_shopping_cart/2" do
    setup do
      cart = shopping_cart_fixture()
      product = product_fixture(%{name: "Coffee", code: "COF", price: Decimal.new("5.10")})
      %{cart: cart, product: product}
    end

    test "returns {:error, :not_found} when product is not in cart", %{cart: cart, product: product} do
      assert {:error, :not_found} = Cashier.remove_item_from_shopping_cart(cart, product)

      # cart remains without items
      cart = Repo.preload(cart, :items)
      assert cart.items == []
    end

    test "returns {:error, :not_found} and keeps existing items when removing a non-existing product from a non-empty cart",
         %{cart: cart, product: product_in_cart} do
      # insert a different product that is not in the cart
      other_product = product_fixture(%{name: "Cookie", code: "CKE", price: Decimal.new("2.25")})

      # add the original product to the cart so it has items
      assert {:ok, %ShoppingCart{} = cart} = Cashier.add_item_to_shopping_cart(cart, product_in_cart)
      cart_before = Repo.preload(cart, :items)
      [%ShoppingCartItem{} = item_before] = cart_before.items

      # attempt to remove a different product that is not present
      assert {:error, :not_found} = Cashier.remove_item_from_shopping_cart(cart, other_product)

      # ensure the cart and item are unchanged
      cart_after = Repo.preload(cart, :items)
      [%ShoppingCartItem{} = item_after] = cart_after.items
      assert item_after.id == item_before.id
      assert item_after.quantity == item_before.quantity
      assert Decimal.eq?(item_after.total_price, item_before.total_price)
    end

    test "decrements quantity and total_price when quantity > 1", %{cart: cart, product: product} do
      # add product twice so quantity becomes 2
      assert {:ok, %ShoppingCart{} = cart} = Cashier.add_item_to_shopping_cart(cart, product)
      assert {:ok, %ShoppingCart{} = cart} = Cashier.add_item_to_shopping_cart(cart, product)

      # now remove once -> quantity should go from 2 to 1 and price to product.price
      assert {:ok, %ShoppingCart{} = cart} = Cashier.remove_item_from_shopping_cart(cart, product)
      cart = Repo.preload(cart, :items)
      [%ShoppingCartItem{} = item] = cart.items
      assert item.quantity == 1
      assert Decimal.eq?(item.total_price, product.price)
    end

    test "deletes the item when quantity == 1", %{cart: cart, product: product} do
      # add product once (quantity == 1)
      assert {:ok, %ShoppingCart{} = cart} = Cashier.add_item_to_shopping_cart(cart, product)

      # remove once -> item should be gone
      assert {:ok, %ShoppingCart{} = cart} = Cashier.remove_item_from_shopping_cart(cart, product)
      cart = Repo.preload(cart, :items)
      assert cart.items == []
    end
  end
end
