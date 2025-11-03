defmodule KantoxWeb.ShoppingCartController do
  use KantoxWeb, :controller

  alias Kantox.Cashier
  alias Kantox.Cashier.ShoppingCart
  alias Kantox.Products
  alias Kantox.Products.Product

  @spec index(conn :: Plug.Conn.t(), params :: map()) :: Plug.Conn.t()
  def index(conn, _params) do
    render(conn, :index, shopping_carts: Cashier.list_shopping_carts())
  end

  @spec show(conn :: Plug.Conn.t(), params :: map()) :: Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    render(conn, :show, shopping_cart: Cashier.get_shopping_cart(id))
  end

  @spec create(conn :: Plug.Conn.t(), params :: map()) :: Plug.Conn.t()
  def create(conn, _params) do
    with {:ok, shopping_cart} <- Cashier.create_shopping_cart() do
      conn
      |> put_status(:created)
      |> render(:show, shopping_cart: shopping_cart)
    end
  end

  @spec create_item(conn :: Plug.Conn.t(), params :: map()) :: Plug.Conn.t()
  def create_item(conn, %{"id" => shopping_cart_id, "product_id" => product_id}) do
    with {:ok, %ShoppingCart{} = shopping_cart} <- fetch_shopping_cart(conn, shopping_cart_id),
         {:ok, %Product{} = product} <- fetch_product(conn, product_id),
         {:ok, %ShoppingCart{} = shopping_cart} <- Cashier.add_item_to_shopping_cart(shopping_cart, product),
         {:ok, %ShoppingCart{} = shopping_cart} <- Cashier.calculate_discount(shopping_cart) do
      conn
      |> put_status(:created)
      |> render(:show, shopping_cart: shopping_cart)
    end
  end

  defp fetch_shopping_cart(conn, shopping_cart_id) do
    shopping_cart = Cashier.get_shopping_cart(shopping_cart_id)

    if is_nil(shopping_cart) do
      conn |> put_status(:not_found) |> render("404.json")
    else
      {:ok, shopping_cart}
    end
  end

  def fetch_product(conn, product_id) do
    product = Products.get_product_by_id(product_id)

    if is_nil(product) do
      conn |> put_status(:not_found) |> render("404.json")
    else
      {:ok, product}
    end
  end
end
