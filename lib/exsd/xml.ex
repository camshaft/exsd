defmodule EXSD.XML do
  use EXSD.Type

  def to_schema(types, entry) do
    {:ok, entry} = Map.fetch(types, entry)
    entry = to_type(entry, types)

    {"xsd:schema", %{"xmlns:xsd" => "http://www.w3.org/2001/XMLSchema"}, [
      entry
    ]}
    |> to_xml_string()
    |> :erlang.iolist_to_binary()
  end

  defp to_xml_string({element, props, children}) do
    props = Enum.map(props, fn({name, value}) -> [" ", name, '="', value, '"'] end)
    ["<", element, props, ">", Enum.map(children, &to_xml_string/1), "</", element, ">"]
  end

  def to_type(%ComplexType{name: name, props: [], children: [%SimpleType{type: type}]}, _) do
    name = to_string(name)
    {"xsd:element", %{"name" => name, "type" => map_type(type)}, []}
  end
  def to_type(%ComplexType{name: name, props: props, children: []}, _) do
    name = to_string(name)
    {"xsd:element", %{"name" => name}, [
      {"xsd:complexType", %{}, prop_types(props)}
    ]}
  end
  def to_type(%ComplexType{name: name, props: props, children: children}, types) do
    name = to_string(name)
    {"xsd:element", %{"name" => name}, [
      {"xsd:complexType", %{}, [
        {"xsd:sequence", %{}, [
          {"xsd:choice", %{"minOccurs" => "0", "maxOccurs" => "unbounded"}, Enum.map(children, &to_type(&1, types))}
        ]}
      | prop_types(props)]}
    ]}
  end
  def to_type(%SimpleType{type: type}, _) do
    {"xsd:element", %{"type" => map_type(type)}, []}
  end
  # TODO implement this
  # def to_type(%Ref{name: name}) do
  #   name = to_string(name)
  #   el = {"xsd:element", %{"type" => name}, []}
  #   {el, []}
  # end

  defp prop_types(props, acc \\ [])
  defp prop_types([], acc) do
    :lists.reverse(acc)
  end
  defp prop_types([{name, %SimpleType{type: type}} | props], acc) do
    attr = {"xsd:attribute", %{"name" => to_string(name), "type" => map_type(type)}, []}
    prop_types(props, [attr | acc])
  end
  defp prop_types([{name, %UnionType{}} | props], acc) do
    # TODO implement this
    attr = {"xsd:attribute", %{"name" => to_string(name), "type" => map_type(:string)}, []}
    prop_types(props, [attr | acc])
  end

  mapping = [
    boolean: :boolean,
    integer: :integer,
    float: :float,
    string: :string,
    uri: :anyURI,
    url: :anyURI
  ]

  for {from, to} <- mapping do
    defp map_type(unquote(from)) do
      unquote("xsd:#{to}")
    end
  end

#   <xs:simpleType name="color" final="restriction" >
#     <xs:restriction base="xs:string">
#         <xs:enumeration value="green" />
#         <xs:enumeration value="red" />
#         <xs:enumeration value="blue" />
#     </xs:restriction>
# </xs:simpleType>
end
