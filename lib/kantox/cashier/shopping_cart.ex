defmodule Kantox.Cashier.ShoppingCart do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query

  alias Ecto.Association.NotLoaded
  alias Kantox.Cashier.ShoppingCartItem

  @type t() :: %__MODULE__{}
  @type status() :: :unpaid | :paid
  @type paid() :: %__MODULE__{
          id: Ecto.UUID.t(),
          status: :paid,
          items: [ShoppingCartItem.t(), ...] | NotLoaded.t(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }
  @type unpaid() :: %__MODULE__{
          id: Ecto.UUID.t(),
          status: :unpaid,
          items: [] | [ShoppingCartItem.t(), ...] | NotLoaded.t(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "shopping_carts" do
    field :status, Ecto.Enum, values: [:unpaid, :paid]

    has_many :items, ShoppingCartItem, preload_order: [desc: :quantity, desc: :updated_at]

    timestamps(type: :utc_datetime)
  end

  @spec query() :: Ecto.Query.t()
  def query, do: preload(from(i in __MODULE__, as: :shopping_cart), items: :product)

  @spec where_id(query :: Ecto.Query.t(), id :: Ecto.UUID.t()) :: Ecto.Query.t()
  def where_id(query \\ query(), id) when is_binary(id) do
    where(query, [shopping_cart: sc], sc.id == ^id)
  end

  @doc false
  def changeset(shopping_cart \\ %__MODULE__{}, attrs) do
    shopping_cart
    |> cast(attrs, [:status])
    |> validate_required([:status])
  end
end
