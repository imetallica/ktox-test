defmodule KantoxWeb.ShoppingCartControllerTest do
  use KantoxWeb.ConnCase, async: true

  import Kantox.DiscountsFixtures
  import Kantox.ProductsFixtures

  describe "GET /api/shopping-carts (index)" do
    test "returns empty list when no carts", %{conn: conn} do
      conn = get(conn, ~p"/api/shopping-carts")
      assert %{"data" => []} = json_response(conn, 200)
    end
  end

  describe "POST /api/shopping-carts (create) and GET /api/shopping-carts/:id (show)" do
    test "creates an unpaid cart and can be fetched by id", %{conn: conn} do
      # Create
      conn = post(conn, ~p"/api/shopping-carts")

      assert %{"data" => %{"id" => cart_id, "status" => "unpaid", "items" => []}} =
               json_response(conn, 201)

      # Show
      conn = get(conn, ~p"/api/shopping-carts/#{cart_id}")

      assert %{"data" => %{"id" => ^cart_id, "status" => "unpaid", "items" => []}} =
               json_response(conn, 200)
    end
  end

  describe "POST /api/shopping-carts/:id/products/:product_id (create_item)" do
    setup do
      product = product_fixture(%{name: "Green tea", code: "GR1", price: Decimal.new("3.11")})

      discount_fixture(%{
        active: true,
        rules: [
          product_rule(%{
            apply_on_product_id: product.id,
            condition: :for_every,
            condition_value: 2,
            value_target: :total_amount,
            value_type: :fixed_value,
            value: Decimal.new("3.11")
          })
        ]
      })

      {:ok, product: product}
    end

    test "adds an item to cart and returns updated cart with discounts applied", %{conn: conn, product: product} do
      # Create cart via API
      create = post(conn, ~p"/api/shopping-carts")
      %{"data" => %{"id" => cart_id}} = json_response(create, 201)

      # Add item
      add_1 = post(conn, ~p"/api/shopping-carts/#{cart_id}/products/#{product.id}")
      add_2 = post(conn, ~p"/api/shopping-carts/#{cart_id}/products/#{product.id}")
      add_3 = post(conn, ~p"/api/shopping-carts/#{cart_id}/products/#{product.id}")
      add_4 = post(conn, ~p"/api/shopping-carts/#{cart_id}/products/#{product.id}")

      assert %{"data" => _} = json_response(add_1, 201)
      assert %{"data" => _} = json_response(add_2, 201)
      assert %{"data" => _} = json_response(add_3, 201)
      assert %{"data" => data} = json_response(add_4, 201)

      assert data["id"] == cart_id
      assert data["status"] == "unpaid"
      assert [item] = data["items"]

      # Verify item structure and values
      assert item["quantity"] == 4
      assert item["total_price"] == "12.44"
      assert item["discount_amount"] == "6.22"
      assert item["final_price"] == "6.22"
      assert item["product"]["id"] == product.id
    end
  end
end
