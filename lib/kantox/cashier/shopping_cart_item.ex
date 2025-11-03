defmodule Kantox.Cashier.ShoppingCartItem do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query

  alias Ecto.Association.NotLoaded
  alias Kantox.Cashier.ShoppingCart
  alias Kantox.Products.Product

  @type t() :: %__MODULE__{
          id: Ecto.UUID.t(),
          quantity: pos_integer(),
          total_price: Decimal.t(),
          discount_amount: Decimal.t(),
          shopping_cart: ShoppingCart.t() | NotLoaded.t(),
          shopping_cart_id: Ecto.UUID.t(),
          product: Product.t() | NotLoaded.t(),
          product_id: Ecto.UUID.t(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "shopping_cart_items" do
    field :quantity, :integer
    field :total_price, :decimal
    field :discount_amount, :decimal, default: 0

    belongs_to :shopping_cart, ShoppingCart
    belongs_to :product, Product

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(shopping_cart_item \\ %__MODULE__{}, attrs) do
    shopping_cart_item
    |> cast(attrs, [:quantity, :total_price, :discount_amount, :shopping_cart_id, :product_id])
    |> validate_required([:quantity, :total_price, :shopping_cart_id, :product_id])
    |> validate_number(:quantity, greater_than: 0)
    |> unique_constraint([:shopping_cart_id, :product_id])
    |> foreign_key_constraint(:shopping_cart_id)
    |> foreign_key_constraint(:product_id)
  end

  @spec query() :: Ecto.Query.t()
  def query, do: from(i in __MODULE__, as: :shopping_cart_item)

  @spec where_product(query :: Ecto.Query.t(), product :: Product.t(), shopping_cart :: ShoppingCart.t()) ::
          Ecto.Query.t()
  def where_product(query \\ query(), %Product{id: product_id}, %ShoppingCart{id: shopping_cart_id}) do
    query
    |> where([shopping_cart_item: i], i.product_id == ^product_id)
    |> where([shopping_cart_item: i], i.shopping_cart_id == ^shopping_cart_id)
  end
end
