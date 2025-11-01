defmodule KantoxWeb.PageController do
  use KantoxWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
