defmodule Kantox.DiscountsFixtures do
  @moduledoc false

  alias Kantox.Cashier.Discount
  alias Kantox.Products.Product
  alias Kantox.Repo

  @doc """
  Builds a Discount struct with sensible defaults and inserts it.
  Accepts attrs to override fields. Defaults to inactive and rules: [].
  """
  def discount_fixture(attrs \\ %{}) do
    defaults = %{
      name: "Discount #{System.unique_integer([:positive])}",
      active: false,
      rules: []
    }

    attrs = Map.merge(defaults, attrs)

    %Discount{}
    |> Map.merge(attrs)
    |> Repo.insert!()
  end

  @doc """
  Returns an embedded product rule struct for convenience.
  Accepts overrides like %{apply_on_product_id: id, condition: :equal, ...}.
  """
  def product_rule(overrides \\ %{}) do
    defaults = %{
      apply_on: :product,
      apply_on_product_id: nil,
      condition: :more_than,
      condition_value: 1,
      value_type: :percentage,
      value: Decimal.new("5.0")
    }

    attrs = Map.merge(defaults, overrides)

    struct(Discount.Rule, attrs)
  end

  @doc """
  Creates a discount with a single product rule for the given product.
  Optionally pass rule_overrides (for the embedded rule) and discount_attrs.
  """
  def discount_with_product_rule_fixture(%Product{id: product_id}, rule_overrides \\ %{}, discount_attrs \\ %{}) do
    rule = product_rule(Map.merge(%{apply_on_product_id: product_id}, rule_overrides))
    attrs = Map.merge(%{rules: [rule]}, discount_attrs)

    discount_fixture(attrs)
  end

  @doc """
  Creates an active discount with a product rule for the given product.
  """
  def active_discount_with_product_rule_fixture(%Product{} = product, rule_overrides \\ %{}) do
    discount_with_product_rule_fixture(product, rule_overrides, %{active: true})
  end
end
