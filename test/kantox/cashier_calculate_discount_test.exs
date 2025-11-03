defmodule Kantox.CashierCalculateDiscountTest do
  use Kantox.DataCase, async: true

  import Kantox.CashierFixtures
  import Kantox.DiscountsFixtures
  import Kantox.ProductsFixtures

  alias Kantox.Cashier
  alias Kantox.Cashier.ShoppingCart

  describe "technical evaluation examples" do
    setup do
      tea = product_fixture(%{name: "Green tea", code: "GR1", price: Decimal.new("3.11")})
      strawberries = product_fixture(%{name: "Strawberries", code: "SR1", price: Decimal.new("5.00")})
      coffee = product_fixture(%{name: "Coffee", code: "CF1", price: Decimal.new("11.23")})
      cart = shopping_cart_fixture()

      discount_fixture(%{
        active: true,
        rules: [
          product_rule(%{
            apply_on_product_id: tea.id,
            condition: :for_every,
            condition_value: 2,
            value_target: :total_amount,
            value_type: :fixed_value,
            value: Decimal.new("3.11")
          }),
          product_rule(%{
            apply_on_product_id: strawberries.id,
            condition: :more_than,
            condition_value: 3,
            value_target: :per_item,
            value_type: :fixed_value,
            value: Decimal.new("4.50")
          }),
          product_rule(%{
            apply_on_product_id: coffee.id,
            condition: :more_than,
            condition_value: 3,
            value_target: :per_item,
            value_type: :percentage,
            value: Decimal.div(100, 3)
          })
        ]
      })

      {:ok, products: %{tea: tea, strawberries: strawberries, coffee: coffee}, cart: cart}
    end

    test "[GR1,SR1,GR1,GR1,CF1] CEO buy-one-get-one-free on Green Tea", %{
      cart: cart,
      products: %{tea: tea, strawberries: strawberries, coffee: coffee}
    } do
      Cashier.add_item_to_shopping_cart(cart, tea)
      Cashier.add_item_to_shopping_cart(cart, strawberries)
      Cashier.add_item_to_shopping_cart(cart, tea)
      Cashier.add_item_to_shopping_cart(cart, tea)
      Cashier.add_item_to_shopping_cart(cart, coffee)

      assert {:ok, %ShoppingCart{} = shopping_cart} = Cashier.calculate_discount(cart)

      assert Cashier.get_final_price(shopping_cart) == Decimal.new("22.45")

      assert shopping_cart.items |> Enum.find(&(&1.product_id == tea.id)) |> Map.get(:total_price) ==
               Decimal.new("9.33")

      assert shopping_cart.items |> Enum.find(&(&1.product_id == tea.id)) |> Map.get(:discount_amount) ==
               Decimal.new("3.11")

      assert shopping_cart.items |> Enum.find(&(&1.product_id == strawberries.id)) |> Map.get(:discount_amount) ==
               Decimal.new("0.00")

      assert shopping_cart.items |> Enum.find(&(&1.product_id == coffee.id)) |> Map.get(:discount_amount) ==
               Decimal.new("0.00")
    end

    test "[GR1,GR1] CEO buy-one-get-one-free on Green Tea", %{
      cart: cart,
      products: %{tea: tea}
    } do
      Cashier.add_item_to_shopping_cart(cart, tea)
      Cashier.add_item_to_shopping_cart(cart, tea)

      assert {:ok, %ShoppingCart{} = shopping_cart} = Cashier.calculate_discount(cart)

      assert Cashier.get_final_price(shopping_cart) == Decimal.new("3.11")

      assert shopping_cart.items |> Enum.find(&(&1.product_id == tea.id)) |> Map.get(:total_price) ==
               Decimal.new("6.22")

      assert shopping_cart.items |> Enum.find(&(&1.product_id == tea.id)) |> Map.get(:discount_amount) ==
               Decimal.new("3.11")
    end

    test "[SR1,SR1,GR1,SR1] COO buy >= 3 and price drops to 4.50 on all Strawberries", %{
      cart: cart,
      products: %{tea: tea, strawberries: strawberries}
    } do
      Cashier.add_item_to_shopping_cart(cart, strawberries)
      Cashier.add_item_to_shopping_cart(cart, strawberries)
      Cashier.add_item_to_shopping_cart(cart, tea)
      Cashier.add_item_to_shopping_cart(cart, strawberries)

      assert {:ok, %ShoppingCart{} = shopping_cart} = Cashier.calculate_discount(cart)

      assert Cashier.get_final_price(shopping_cart) == Decimal.new("16.61")

      assert shopping_cart.items |> Enum.find(&(&1.product_id == tea.id)) |> Map.get(:total_price) ==
               Decimal.new("3.11")

      assert shopping_cart.items |> Enum.find(&(&1.product_id == tea.id)) |> Map.get(:discount_amount) ==
               Decimal.new("0.00")

      assert shopping_cart.items |> Enum.find(&(&1.product_id == strawberries.id)) |> Map.get(:total_price) ==
               Decimal.new("15.00")

      assert shopping_cart.items |> Enum.find(&(&1.product_id == strawberries.id)) |> Map.get(:discount_amount) ==
               Decimal.new("1.50")
    end

    test "[GR1,CF1,SR1,CF1,CF1] CTO buy >= 3 and price drops to 2/3 on all Coffee", %{
      cart: cart,
      products: %{tea: tea, strawberries: strawberries, coffee: coffee}
    } do
      Cashier.add_item_to_shopping_cart(cart, tea)
      Cashier.add_item_to_shopping_cart(cart, coffee)
      Cashier.add_item_to_shopping_cart(cart, strawberries)
      Cashier.add_item_to_shopping_cart(cart, coffee)
      Cashier.add_item_to_shopping_cart(cart, coffee)

      assert {:ok, %ShoppingCart{} = shopping_cart} = Cashier.calculate_discount(cart)

      assert Cashier.get_final_price(shopping_cart) == Decimal.new("30.57")

      assert shopping_cart.items |> Enum.find(&(&1.product_id == tea.id)) |> Map.get(:total_price) ==
               Decimal.new("3.11")

      assert shopping_cart.items |> Enum.find(&(&1.product_id == tea.id)) |> Map.get(:discount_amount) ==
               Decimal.new("0.00")

      assert shopping_cart.items |> Enum.find(&(&1.product_id == coffee.id)) |> Map.get(:total_price) ==
               Decimal.new("33.69")

      assert shopping_cart.items |> Enum.find(&(&1.product_id == coffee.id)) |> Map.get(:discount_amount) ==
               Decimal.new("11.23")

      assert shopping_cart.items |> Enum.find(&(&1.product_id == strawberries.id)) |> Map.get(:total_price) ==
               Decimal.new("5.00")

      assert shopping_cart.items |> Enum.find(&(&1.product_id == strawberries.id)) |> Map.get(:discount_amount) ==
               Decimal.new("0.00")
    end
  end

  describe "calculate_discount/1" do
    setup do
      cart = shopping_cart_fixture()
      product = product_fixture(%{name: "Test", code: "TST", price: Decimal.new("2.00")})
      {:ok, %{cart: cart, product: product}}
    end

    test "no active discount leaves items untouched", %{cart: cart, product: product} do
      Cashier.add_item_to_shopping_cart(cart, product)
      Cashier.add_item_to_shopping_cart(cart, product)
      Cashier.add_item_to_shopping_cart(cart, product)

      assert {:ok, %ShoppingCart{} = shopping_cart} = Cashier.calculate_discount(cart)

      item = Enum.find(shopping_cart.items, &(&1.product_id == product.id))
      assert item.total_price == Decimal.new("6.00")
      assert item.discount_amount == Decimal.new("0.00")
      assert Cashier.get_final_price(shopping_cart) == Decimal.new("6.00")
    end

    test ":for_every per-item percentage applies to multiples only", %{cart: cart, product: product} do
      # Add 5 units
      Enum.each(1..5, fn _ -> Cashier.add_item_to_shopping_cart(cart, product) end)

      # Active discount: For every 2 items, 1% discount per discounted unit (4 units discounted)
      discount_fixture(%{
        active: true,
        rules: [
          product_rule(%{
            apply_on_product_id: product.id,
            condition: :for_every,
            condition_value: 2,
            value_target: :per_item,
            value_type: :percentage,
            value: Decimal.new("1.0")
          })
        ]
      })

      assert {:ok, %ShoppingCart{} = shopping_cart} = Cashier.calculate_discount(cart)

      item = Enum.find(shopping_cart.items, &(&1.product_id == product.id))

      # 5 items => discounted units = div(5,2)*2 = 4; per-unit discount = 2.00 * 0.01 = 0.02; total = 0.08
      assert item.total_price == Decimal.new("10.00")
      assert item.discount_amount == Decimal.new("0.08")
      assert Cashier.get_final_price(shopping_cart) == Decimal.new("9.92")
    end

    test ":for_every total-amount fixed_value applies once per group with leftover", %{cart: cart, product: product} do
      # Add 5 units
      Enum.each(1..5, fn _ -> Cashier.add_item_to_shopping_cart(cart, product) end)

      # Active discount: For every 2 items, discount the total by a fixed value equal to unit price (BOGO style)
      discount_fixture(%{
        active: true,
        rules: [
          product_rule(%{
            apply_on_product_id: product.id,
            condition: :for_every,
            condition_value: 2,
            value_target: :total_amount,
            value_type: :fixed_value,
            value: Decimal.new("2.00")
          })
        ]
      })

      assert {:ok, %ShoppingCart{} = shopping_cart} = Cashier.calculate_discount(cart)

      item = Enum.find(shopping_cart.items, &(&1.product_id == product.id))

      # 5 items => pairs = 2 => discount = 2 * 2.00 = 4.00
      assert item.total_price == Decimal.new("10.00")
      assert item.discount_amount == Decimal.new("4.00")
      assert Cashier.get_final_price(shopping_cart) == Decimal.new("6.00")
    end
  end
end
