defmodule Kantox.Cashier.Discount do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query

  alias Ecto.Association.NotLoaded
  alias Kantox.Products.Product

  @type t() :: %__MODULE__{}

  @type rule_applies_on() :: :product
  @type rule_condition() :: :for_every | :more_than
  @type rule_value_target() :: :per_item | :total_amount
  @type rule_value_type() :: :percentage | :fixed_value | :fixed_deduction

  @type inactive() :: %__MODULE__{
          id: Ecto.UUID.t(),
          name: String.t(),
          active: false,
          rules: [] | [product_rule(), ...],
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }
  @type active() :: %__MODULE__{
          id: Ecto.UUID.t(),
          name: String.t(),
          active: true,
          rules: [product_rule(), ...],
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }
  @type product_rule() :: %__MODULE__.Rule{
          id: Ecto.UUID.t(),
          apply_on: :product,
          apply_on_product: Product.t() | NotLoaded.t(),
          apply_on_product_id: Ecto.UUID.t(),
          condition: :equal | :greater_than,
          condition_value: non_neg_integer(),
          value_type: :percentage | :fixed_value | :fixed_deduction,
          value: Decimal.t()
        }

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "discounts" do
    field :name, :string
    field :active, :boolean, default: false

    embeds_many :rules, Rule, on_replace: :delete do
      field :apply_on, Ecto.Enum, values: [:product]
      belongs_to :apply_on_product, Product, type: :binary_id

      field :condition, Ecto.Enum, values: [:for_every, :more_than]
      field :condition_value, :integer

      field :value_target, Ecto.Enum, values: [:per_item, :total_amount]
      field :value_type, Ecto.Enum, values: [:percentage, :fixed_value, :fixed_deduction]
      field :value, :decimal
    end

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(discount, attrs) do
    discount
    |> cast(attrs, [:name, :active])
    |> cast_embed(:rules, with: &rule_changeset/2)
    |> validate_required([:name])
  end

  @spec query() :: Ecto.Query.t()
  def query, do: from(i in __MODULE__, as: :discount)

  @spec where_active(query :: Ecto.Query.t()) :: Ecto.Query.t()
  def where_active(query \\ query()) do
    query
    |> where([discount: d], d.active == true)
    |> preload(rules: [:apply_on_product])
  end

  defp rule_changeset(rule, attrs) do
    rule
    |> cast(attrs, [:apply_on, :apply_on_product_id, :condition, :condition_value, :value_type, :value])
    |> validate_required([:apply_on, :condition, :condition_value, :value_type, :value])
    |> check_rules()
  end

  defp check_rules(changeset) do
    apply_on = get_field(changeset, :apply_on)

    if apply_on == :product do
      validate_required(changeset, :apply_on_product_id)
    else
      changeset
    end
  end
end
