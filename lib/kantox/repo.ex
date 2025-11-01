defmodule Kantox.Repo do
  use Ecto.Repo,
    otp_app: :kantox,
    adapter: Ecto.Adapters.Postgres
end
