defmodule Kantox.Repo.Migrations.CreateDiscounts do
  use Ecto.Migration

  def change do
    create table(:discounts, primary_key: false) do
      timestamps(type: :utc_datetime)

      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :active, :boolean, null: false, default: false
      add :rules, :jsonb, null: false, default: "[]"
    end
  end
end
