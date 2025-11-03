defmodule Kantox.Repo.Migrations.CreateProducts do
  use Ecto.Migration

  def change do
    create table(:products, primary_key: false) do
      timestamps(type: :utc_datetime)
      add :id, :binary_id, primary_key: true
      add :name, :string
      add :code, :string
      add :price, :decimal
    end
  end
end
