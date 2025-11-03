defmodule Kantox.Products.Product do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  @type t() :: %__MODULE__{
          id: binary() | nil,
          name: String.t() | nil,
          code: String.t() | nil,
          price: Decimal.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "products" do
    field :name, :string
    field :code, :string
    field :price, :decimal

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(product, attrs) do
    product
    |> cast(attrs, [:name, :code, :price])
    |> validate_required([:name, :code, :price])
  end
end
