defmodule Kantox.Cashier do
  @moduledoc false

  alias Ecto.Multi
  alias Kantox.Cashier.Discount
  alias Kantox.Cashier.ShoppingCart
  alias Kantox.Cashier.ShoppingCartItem
  alias Kantox.Products.Product
  alias Kantox.Repo

  @spec list_shopping_carts() :: [ShoppingCart.t(), ...] | []
  def list_shopping_carts do
    Repo.all(ShoppingCart.query())
  end

  @spec get_shopping_cart(id :: Ecto.UUID.t()) :: ShoppingCart.t() | nil
  def get_shopping_cart(id) when is_binary(id) do
    Repo.one(ShoppingCart.where_id(id))
  end

  @spec create_shopping_cart() :: {:ok, ShoppingCart.unpaid()} | {:error, Ecto.Changeset.t()}
  def create_shopping_cart do
    %ShoppingCart{}
    |> ShoppingCart.changeset(%{status: :unpaid})
    |> Repo.insert()
    |> then(fn
      {:ok, %ShoppingCart{} = shopping_cart} -> {:ok, Repo.preload(shopping_cart, items: :product)}
      {:error, changeset} -> {:error, changeset}
    end)
  end

  @spec get_final_price(unpaid_shopping_cart :: ShoppingCart.unpaid()) :: Decimal.t()
  def get_final_price(%ShoppingCart{items: items}) do
    Enum.reduce(items, 0, fn %ShoppingCartItem{total_price: total_price, discount_amount: discount_amount}, acc ->
      Decimal.add(acc, Decimal.sub(total_price, discount_amount || 0))
    end)
  end

  @spec calculate_discount(unpaid_shopping_cart :: ShoppingCart.unpaid()) ::
          {:ok, ShoppingCart.unpaid()} | {:error, term()}
  def calculate_discount(%ShoppingCart{status: :unpaid} = unpaid_shopping_cart) do
    unpaid_shopping_cart
    |> Repo.preload([items: [:product]], force: true)
    |> do_calculate_discount(get_active_discount())
    |> Enum.reduce(Multi.new(), fn changeset, multi ->
      Multi.update(multi, System.unique_integer(), changeset)
    end)
    |> Repo.transact()
    |> then(fn
      {:ok, _results} ->
        {:ok, Repo.preload(unpaid_shopping_cart, [items: :product], force: true)}

      {:error, _, reason, _} ->
        {:error, reason}
    end)
  end

  @spec get_active_discount() :: nil | Discount.active()
  def get_active_discount, do: Repo.one(Discount.where_active())

  @spec create_discount(name :: String.t()) :: {:ok, Discount.inactive()} | {:error, Ecto.Changeset.t()}
  def create_discount(name) when is_binary(name) do
    %Discount{} |> Discount.changeset(%{name: name, rules: []}) |> Repo.insert()
  end

  @type rule_attrs :: %{
          condition: Discount.rule_condition(),
          condition_value: non_neg_integer(),
          value_type: Discount.rule_value_type(),
          value: Decimal.t()
        }
  @spec create_product_discount_rule(discount :: Discount.inactive(), product :: Product.t(), rule_attrs :: rule_attrs()) ::
          {:ok, Discount.inactive()} | {:error, Ecto.Changeset.t()}
  def create_product_discount_rule(%Discount{} = discount, %Product{} = product, attrs) do
    rule_attrs =
      Map.merge(attrs, %{
        apply_on: :product,
        apply_on_product_id: product.id
      })

    discount.rules
    |> Enum.find(fn %Discount.Rule{apply_on_product_id: product_id} -> product_id == product.id end)
    |> then(fn
      nil ->
        [rule_attrs | Enum.map(discount.rules, &Map.from_struct/1)]

      %Discount.Rule{} = rule ->
        unmatched_rules = Enum.reject(discount.rules, fn %Discount.Rule{id: id} -> id == rule.id end)

        updated_rule =
          Map.merge(
            %{
              id: rule.id,
              apply_on: rule.apply_on,
              apply_on_product_id: rule.apply_on_product_id
            },
            rule_attrs
          )

        [updated_rule | Enum.map(unmatched_rules, &Map.from_struct/1)]
    end)
    |> then(fn rules ->
      discount
      |> Discount.changeset(%{rules: rules})
      |> Repo.update()
    end)
  end

  @spec remove_product_discount_rule(discount :: Discount.inactive(), product :: Product.t()) ::
          {:ok, Discount.inactive()} | {:error, Ecto.Changeset.t()}
  def remove_product_discount_rule(%Discount{} = discount, %Product{} = product) do
    updated_rules =
      discount.rules
      |> Enum.reject(fn %Discount.Rule{apply_on_product_id: product_id} -> product_id === product.id end)
      |> Enum.map(fn %Discount.Rule{} = rule ->
        %{
          apply_on: rule.apply_on,
          apply_on_product_id: rule.apply_on_product_id,
          condition: rule.condition,
          condition_value: rule.condition_value,
          value_type: rule.value_type,
          value: rule.value
        }
      end)

    discount
    |> Discount.changeset(%{rules: updated_rules})
    |> Repo.update()
  end

  @spec activate_discount(discount :: Discount.inactive() | Discount.active()) ::
          {:ok, Discount.active()} | {:error, Ecto.Changeset.t()}
  def activate_discount(%Discount{} = discount) do
    Multi.new()
    |> Multi.update_all(:discounts, Discount, set: [active: false])
    |> Multi.update(:discount, Discount.changeset(discount, %{active: true}))
    |> Repo.transact()
    |> then(fn
      {:error, _, reason, _} -> {:error, reason}
      {:ok, %{discount: %Discount{active: true} = discount}} -> {:ok, discount}
    end)
  end

  @spec add_item_to_shopping_cart(
          unpaid_shopping_cart :: ShoppingCart.unpaid(),
          product :: Product.t()
        ) ::
          {:ok, ShoppingCart.unpaid()} | {:error, Ecto.Changeset.t()}
  def add_item_to_shopping_cart(%ShoppingCart{status: :unpaid} = shopping_cart, %Product{} = product) do
    Multi.new()
    |> Multi.one(:maybe_item, ShoppingCartItem.where_product(product, shopping_cart))
    |> Multi.merge(fn
      %{maybe_item: nil} ->
        Multi.insert(
          Multi.new(),
          :item,
          ShoppingCartItem.changeset(%{
            shopping_cart_id: shopping_cart.id,
            product_id: product.id,
            quantity: 1,
            total_price: product.price
          })
        )

      %{maybe_item: %ShoppingCartItem{} = item} ->
        Multi.update(
          Multi.new(),
          :item,
          ShoppingCartItem.changeset(item, %{
            quantity: item.quantity + 1,
            total_price: Decimal.mult(product.price, item.quantity + 1)
          })
        )
    end)
    |> Repo.transact()
    |> case do
      {:ok, _item_or_result} ->
        {:ok, Repo.preload(shopping_cart, [:items], force: true)}

      {:error, _, changeset = %Ecto.Changeset{}, _} ->
        {:error, changeset}
    end
  end

  @spec remove_item_from_shopping_cart(unpaid_shopping_cart :: ShoppingCart.unpaid(), product :: Product.t()) ::
          {:ok, ShoppingCart.unpaid()} | {:error, :not_found} | {:error, Ecto.Changeset.t()}
  def remove_item_from_shopping_cart(%ShoppingCart{status: :unpaid} = shopping_cart, %Product{} = product) do
    Multi.new()
    |> Multi.one(:maybe_item, ShoppingCartItem.where_product(product, shopping_cart))
    |> Multi.merge(fn
      %{maybe_item: nil} ->
        Multi.error(Multi.new(), :item, :not_found)

      %{maybe_item: %ShoppingCartItem{quantity: quantity} = item} when quantity > 1 ->
        changeset =
          ShoppingCartItem.changeset(item, %{
            quantity: item.quantity - 1,
            total_price: Decimal.mult(product.price, item.quantity - 1)
          })

        Multi.update(Multi.new(), :item, changeset)

      %{maybe_item: %ShoppingCartItem{} = item} ->
        Multi.delete(Multi.new(), :item, item)
    end)
    |> Repo.transact()
    |> case do
      {:ok, _item_or_result} ->
        {:ok, Repo.preload(shopping_cart, [:items], force: true)}

      {:error, _, reason, _} ->
        {:error, reason}
    end
  end

  # No-op: no active discount found, so nothing to update
  defp do_calculate_discount(%ShoppingCart{} = _unpaid_shopping_cart, nil), do: []

  defp do_calculate_discount(%ShoppingCart{} = unpaid_shopping_cart, %Discount{active: true} = discount) do
    for %ShoppingCartItem{product: %Product{} = shopping_cart_product} = shopping_cart_item <- unpaid_shopping_cart.items,
        %Discount.Rule{apply_on: :product, apply_on_product: %Product{} = discount_product} = rule <- discount.rules,
        discount_product.id == shopping_cart_product.id do
      apply_rule(shopping_cart_item, rule)
    end
  end

  defp apply_rule(
         %ShoppingCartItem{quantity: quantity, product: %Product{price: price}} = shopping_cart_item,
         %Discount.Rule{
           condition: :for_every,
           condition_value: for_every_number_of_items,
           value_target: :per_item,
           value_type: :percentage,
           value: percentage_discount
         }
       )
       when quantity >= for_every_number_of_items do
    times_applicable = div(quantity, for_every_number_of_items) * for_every_number_of_items
    percentage_discount_div_100 = Decimal.mult(percentage_discount, Decimal.new("0.01"))
    discount_amount_per_item = Decimal.mult(price, percentage_discount_div_100)

    ShoppingCartItem.changeset(shopping_cart_item, %{
      discount_amount: Decimal.mult(discount_amount_per_item, times_applicable)
    })
  end

  defp apply_rule(
         %ShoppingCartItem{quantity: quantity, total_price: total_price, product: %Product{}} = shopping_cart_item,
         %Discount.Rule{
           condition: :for_every,
           condition_value: for_every_number_of_items,
           value_target: :per_item,
           value_type: :fixed_value,
           value: fixed_value
         }
       )
       when quantity >= for_every_number_of_items do
    times_applicable = div(quantity, for_every_number_of_items) * for_every_number_of_items
    appliable_fixed_value = Decimal.mult(fixed_value, times_applicable)

    ShoppingCartItem.changeset(shopping_cart_item, %{
      discount_amount: Decimal.sub(total_price, appliable_fixed_value)
    })
  end

  defp apply_rule(%ShoppingCartItem{quantity: quantity, product: %Product{}} = shopping_cart_item, %Discount.Rule{
         condition: :for_every,
         condition_value: for_every_number_of_items,
         value_target: :total_amount,
         value_type: :fixed_value,
         value: fixed_value
       })
       when quantity >= for_every_number_of_items do
    times_applicable = div(quantity, for_every_number_of_items)
    appliable_fixed_value = Decimal.mult(fixed_value, times_applicable)

    ShoppingCartItem.changeset(shopping_cart_item, %{
      discount_amount: appliable_fixed_value
    })
  end

  defp apply_rule(
         %ShoppingCartItem{quantity: quantity, product: %Product{price: price}} = shopping_cart_item,
         %Discount.Rule{
           condition: :more_than,
           condition_value: more_than_number_of_items,
           value_target: :per_item,
           value_type: :percentage,
           value: fixed_value
         }
       )
       when quantity >= more_than_number_of_items do
    percentage_discount_div_100 = Decimal.mult(fixed_value, Decimal.new("0.01"))
    discount_amount_per_item = Decimal.mult(price, percentage_discount_div_100)

    ShoppingCartItem.changeset(shopping_cart_item, %{
      discount_amount: Decimal.mult(discount_amount_per_item, quantity)
    })
  end

  defp apply_rule(
         %ShoppingCartItem{quantity: quantity, total_price: total_price, product: %Product{}} = shopping_cart_item,
         %Discount.Rule{
           condition: :more_than,
           condition_value: more_than_number_of_items,
           value_target: :per_item,
           value_type: :fixed_value,
           value: fixed_value
         }
       )
       when quantity >= more_than_number_of_items do
    appliable_fixed_value = Decimal.mult(fixed_value, quantity)

    ShoppingCartItem.changeset(shopping_cart_item, %{
      discount_amount: Decimal.sub(total_price, appliable_fixed_value)
    })
  end

  defp apply_rule(%ShoppingCartItem{} = shopping_cart_item, _rule),
    do: ShoppingCartItem.changeset(shopping_cart_item, %{discount_amount: 0})
end
