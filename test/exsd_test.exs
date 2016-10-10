defmodule Test.EXSD do
  use ExUnit.Case

  defmodule AddressParser do
    use EXSD

    defentry :Address, "/address"

    defel :Address, type: "residential" | "commercial" = "residential" do
      defel street(), string
      defel :"postal-code", integer
      defel empty
    end
  end

  test "address" do
    xml = """
    <Address>
      <street>123 Fake Street</street>
      <postal-code>5678</postal-code>
    </Address>
    """

    res = EXSD.parse!("/address", xml)

    alias AddressParser.Address
    assert %Address{
      props: %{type: "residential"},
      children: [
        %Address.Street{
          children: [
            "123 " <> _
          ]
        },
        %Address.PostalCode{
          children: [
            5678
          ]
        }
      ]
    } = res
  end
end
