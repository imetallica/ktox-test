# Kantox

## About the exposed API

Since the Technical Evaluation asks for a service, I've created a Phoenix project with the following endpoints available:

```
|------|----------------------------------------------|
|  GET | /api/shopping-carts -------------------------|
| POST | /api/shopping-carts -------------------------|
|  GET | /api/shopping-carts/:id ---------------------|
| POST | /api/shopping-carts/:id/products/:product_id |
|------|----------------------------------------------|
```

## About the Database Schemas

We have basically 4 schemas:

  - `Kantox.Products.Product`
  - `Kantox.Cashier.ShoppingCart`
  - `Kantox.Cashier.ShoppingCartItem`
  - `Kantox.Cashier.Discount`


### `Kantox.Cashier.Discount`

When I originally built this schema, I thought only one of the set of given rules would be active, but that was not the case, but I modeled it in a way to allow multiple rules under the same discount schema - which in the end fulfill the needs of the implementation. Inside, you will see the following:

```elixir
embeds_many :rules, Rule, on_replace: :delete do
    field :apply_on, Ecto.Enum, values: [:product]
    belongs_to :apply_on_product, Product, type: :binary_id

    field :condition, Ecto.Enum, values: [:for_every, :more_than]
    field :condition_value, :integer

    field :value_target, Ecto.Enum, values: [:per_item, :total_amount]
    field :value_type, Ecto.Enum, values: [:percentage, :fixed_value, :fixed_deduction]
    field :value, :decimal
end
```

Upon combinating the `condition`, `value_target` and `value_type` we can achieve all use cases described in the test example and even others. For example:

- BOGO (Buy One Get One Free): `%{condition: :for_every, condition_value: 2, value_target: :total_amount, value_type: :fixed_value, value: "3.11"}` (For every two products, we set the value of discount as 3.11 - the original price of a single product - CEO rule).
- Buy x or more, Fixed Price: `%{condition: :more_than, condition_value: 3, value_target: :per_item, value_type: :fixed_value, value: "4.50"}` (COO rule).
- Buy x or more, Price Drop: `%{condition: :more_than, condition_value: 3, value_target: :per_item, value_type: :percentage, value: Decimal.div(100, 3)}` (CTO rule).

You can check these rules in action in `test/kantox/cashier_calculate_discount_test.exs`

### `Kantox.Cashier.ShoppingCartItem`

Things to note in this schema:

```elixir
schema "shopping_cart_items" do
    field :quantity, :integer
    field :total_price, :decimal
    field :discount_amount, :decimal, default: 0

    belongs_to :shopping_cart, ShoppingCart
    belongs_to :product, Product

    timestamps(type: :utc_datetime)
end
```

- `quantity`: The number of `product` items in the shopping cart.
- `total_price`: The `quantity * product.price` - raw total price, without discount.
- `discount_amount`: The discount to be applied in the items.

And to calculate the final price of the products, you do: `total_price - discount_amount`

### `Kantox.Cashier.ShoppingCart`

Things to note in this schema:

```elixir
schema "shopping_carts" do
    field :status, Ecto.Enum, values: [:unpaid, :paid]

    has_many :items, ShoppingCartItem, preload_order: [desc: :quantity, desc: :updated_at]

    timestamps(type: :utc_datetime)
end
```

The preload order is just to make it consistent when returning data by ordering by the number of items and when it was last updated.

## About Contexts

Most business rules live in `lib/kantox/cashier.ex`. Things to note:

- I like to give names to things, hence why, in some of these functions, you will see as typespecs and as pattern matching constructs `ShoppingCart.unpaid()` instead of a simple `ShoppingCart.t()`. This makes it more explicit what type of data, which state, we accept it and, what are the state transitions.
- Using explicit names helps us share and speak the same language and know what are the terms we are refeering to when speaking with the customer / business user of the system - ubiquitous language.
- One pitfall of the implementation is the high usage of `Repo.preload/3` that requires multiple queries into the database. For the current use case we have I don't see it as an issue, but in high load environment this may become a bottleneck. A way of fixing it would be to move some of these preloads into a single one, but we may loose some of the explicitness of the code.

The most complex function in this context is the `calculate_discount/1`, here are some of the interesting parts:

- `apply_rule/2` takes a `%ShoppingCartItem{}` and a `%Discount.Rule{}`, that applies to a specific `%Product{}`, and applies the discount based on the rules defined in the `%Discount.Rule{}`. One pitifall of this strategy is that, if we have multiple rules that apply to the same product, they will get overriden. To solve this pitfall, we may need to add another set of fields that configure either, if the rule is to be overriden or if it's a cumulative discount and the order these discounts should be applied.
- I have not implemented all the use cases the `%Discount.Rule{}` would support since only 3 use cases were required by the technical evaluation so, currently, there's a catch all for the other clauses that don't do anything at the moment. 

## Tests 

I added basic tests for the functions that effectively implement side effects. Also, I implemented the use case tests outlined in the Technical Evaluation in the `Kantox.CashierCalculateDiscountTest.describe "technical evaluation examples"`. To improve the situation, I would do the following things:

- Add property tests to catch possible corner cases. They are great for this.
- Randomize the order when items are added into a shopping cart, so we know the calculation is correct in any case. Property tests could help here.
- Add some Business Driven Test rules for specific cases outlined by the business.
- Apply `mix credo --strict` rules
- Make `mix dialyzer` as strict as possible. 