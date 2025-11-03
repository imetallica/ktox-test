defmodule Kantox.Repo.Migrations.CreateShoppingCartItems do
  use Ecto.Migration

  def change do
    create table(:shopping_cart_items, primary_key: false) do
      timestamps(type: :utc_datetime)
      add :id, :binary_id, primary_key: true
      add :quantity, :integer, null: false
      add :total_price, :decimal, null: false, scale: 2, precision: 10
      add :discount_amount, :decimal, null: false, default: 0, scale: 2, precision: 10
      add :shopping_cart_id, references(:shopping_carts, type: :binary_id), null: false
      add :product_id, references(:products, type: :binary_id), null: false
    end

    create unique_index(:shopping_cart_items, [:shopping_cart_id, :product_id],
             name: :unique_product_per_cart
           )

    create index(:shopping_cart_items, [:shopping_cart_id])
    create index(:shopping_cart_items, [:product_id])
  end
end
