defmodule Kantox.Repo.Migrations.CreateShoppingCarts do
  use Ecto.Migration

  def change do
    create table(:shopping_carts, primary_key: false) do
      timestamps(type: :utc_datetime)
      add :id, :binary_id, primary_key: true
      add :status, :string, null: false, default: "unpaid"
    end
  end
end
