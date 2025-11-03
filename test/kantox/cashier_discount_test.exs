defmodule Kantox.CashierDiscountTest do
  use Kantox.DataCase, async: true

  import Kantox.DiscountsFixtures
  import Kantox.ProductsFixtures

  alias Kantox.Cashier
  alias Kantox.Cashier.Discount
  alias Kantox.Products.Product
  alias Kantox.Repo

  describe "get_active_discount/0" do
    test "returns nil when there is no active discount" do
      assert Cashier.get_active_discount() == nil

      # insert an inactive discount and still expect nil
      discount_fixture(%{name: "Promo X", active: false})

      assert Cashier.get_active_discount() == nil
    end

    test "returns the active discount with product rule and preloaded product" do
      product = product_fixture(%{name: "Tea", code: "TEA", price: Decimal.new("3.50")})

      # an extra inactive discount to ensure we pick the active one
      discount_fixture(%{name: "Inactive Promo", active: false})

      active_discount_with_product_rule_fixture(product, %{
        condition: :more_than,
        condition_value: 2,
        value_type: :percentage,
        value: Decimal.new("10.0")
      })

      assert %Discount{active: true, rules: [rule]} = Cashier.get_active_discount()
      assert rule.apply_on == :product
      assert rule.apply_on_product_id == product.id

      # We expect the apply_on_product to be preloaded as a Product struct
      assert %Product{id: prod_id} = rule.apply_on_product
      assert prod_id == product.id
    end
  end

  describe "create_discount/1" do
    test "creates an inactive discount with empty rules" do
      assert {:ok, %Discount{} = discount} = Cashier.create_discount("Promo A")
      assert discount.active == false
      assert discount.rules == []

      persisted = Repo.get!(Discount, discount.id)
      assert persisted.name == "Promo A"
      assert persisted.active == false
      assert persisted.rules == []
    end
  end

  describe "create_product_discount_rule/3" do
    setup do
      product_a = product_fixture(%{name: "Tea", code: "TEA"})
      product_b = product_fixture(%{name: "Coffee", code: "COF"})

      discount =
        discount_with_product_rule_fixture(
          product_a,
          %{
            condition: :more_than,
            condition_value: 2,
            value_type: :percentage,
            value: Decimal.new("10.0")
          },
          %{name: "Promo Update", active: false}
        )

      %{discount: discount, product_a: product_a, product_b: product_b}
    end

    test "updates existing rule for the given product", %{discount: discount, product_a: product} do
      attrs = %{condition: :more_than, condition_value: 3, value_type: :fixed_value, value: Decimal.new("2.00")}

      assert {:ok, %Discount{} = updated} = Cashier.create_product_discount_rule(discount, product, attrs)

      assert length(updated.rules) == 1
      [rule] = updated.rules
      assert rule.apply_on == :product
      assert rule.apply_on_product_id == product.id
      assert rule.condition == :more_than
      assert rule.condition_value == 3
      assert rule.value_type == :fixed_value
      assert Decimal.eq?(rule.value, Decimal.new("2.00"))
    end

    test "inserts a new rule when none exists for the given product", %{discount: discount, product_b: other_product} do
      attrs = %{condition: :more_than, condition_value: 5, value_type: :percentage, value: Decimal.new("15.0")}

      assert {:ok, %Discount{} = updated} = Cashier.create_product_discount_rule(discount, other_product, attrs)

      # existing rule preserved and a new rule for other_product was added
      assert length(updated.rules) == 2
      assert Enum.any?(updated.rules, &(&1.apply_on_product_id == other_product.id))

      new_rule = Enum.find(updated.rules, &(&1.apply_on_product_id == other_product.id))
      assert new_rule.apply_on == :product
      assert new_rule.condition == :more_than
      assert new_rule.condition_value == 5
      assert new_rule.value_type == :percentage
      assert Decimal.eq?(new_rule.value, Decimal.new("15.0"))
    end
  end

  describe "remove_product_discount_rule/2" do
    setup do
      product_a = product_fixture(%{name: "Tea", code: "TEA"})
      product_b = product_fixture(%{name: "Coffee", code: "COF"})

      discount =
        discount_fixture(%{
          name: "Promo Remove",
          active: false,
          rules: [
            product_rule(%{
              apply_on_product_id: product_a.id,
              condition: :more_than,
              condition_value: 2,
              value_type: :percentage,
              value: Decimal.new("10.0")
            }),
            product_rule(%{
              apply_on_product_id: product_b.id,
              condition: :more_than,
              condition_value: 3,
              value_type: :fixed_value,
              value: Decimal.new("2.00")
            })
          ]
        })

      %{discount: discount, product_a: product_a, product_b: product_b}
    end

    test "removes the rule when the product matches", %{discount: discount, product_a: product_a} do
      assert {:ok, %Discount{} = updated} = Cashier.remove_product_discount_rule(discount, product_a)
      assert length(updated.rules) == 1
      [remaining] = updated.rules
      refute remaining.apply_on_product_id == product_a.id
    end

    test "no-ops when no rule exists for the product", %{discount: discount} do
      other = product_fixture(%{name: "Cookie", code: "CKE"})
      assert {:ok, %Discount{} = updated} = Cashier.remove_product_discount_rule(discount, other)
      assert length(updated.rules) == 2
    end
  end

  describe "activate_discount/1" do
    test "sets exactly one active discount and deactivates others" do
      d1 = discount_fixture(%{name: "D1", active: false})
      d2 = discount_fixture(%{name: "D2", active: false})

      assert {:ok, %Discount{active: true, id: active_id}} = Cashier.activate_discount(d1)

      all = Repo.all(Discount)
      assert Enum.count(all, & &1.active) == 1
      assert Enum.any?(all, &(&1.id == active_id && &1.active))

      # The getter returns the same active discount and preloads rules
      active = Cashier.get_active_discount()
      assert %Discount{id: ^active_id, active: true} = active

      # activating another discount flips the active one
      assert {:ok, %Discount{active: true, id: active_id2}} = Cashier.activate_discount(d2)
      assert active_id2 != active_id
      all = Repo.all(Discount)
      assert Enum.count(all, & &1.active) == 1
    end
  end
end
