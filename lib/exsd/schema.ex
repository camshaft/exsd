defmodule EXSD.Schema do
  defmacro __using__(opts) do
    xsd = Keyword.fetch!(opts, :xsd)
    quote do
      @xsd unquote(xsd)
      @before_compile unquote(__MODULE__)
    end
  end

  import Record
  defrecord :type, [:name, :tp, :els, :attrs, :anyAttr, :nillable, :nr, :nm, :mx, :mxd, :typeName]
  defrecord :el, [:alts, :mn, :mx, :nillable, :nr]
  defrecord :alt, [:tag, :type, :nxt, :mn, :mx, :rl, :anyInfo]
  defrecord :attr, :att, [:name, :nr, :opt, :tp]

  def extract_element_names(model) do
    model
    |> elem(1)
    |> Stream.map(fn
      (type(name: orig, els: [el(alts: [alt(tag: tag)])])) ->
        tag = Atom.to_string(tag)
        fix = String.replace(tag, "-", "/")

        to = orig
        |> Atom.to_string()
        |> String.replace("-", "/")
        |> String.replace(fix, tag)
        |> String.to_atom()

        {orig, to}
      (type(name: orig)) ->
        to = fix_name(orig)
        {orig, to}
    end)
    |> Enum.into(%{})
  end

  def extract_attr_names(model) do
    model
    |> elem(1)
    |> Enum.map(fn(type(name: name, attrs: attrs)) ->
      attrs = attrs
      |> Enum.map(fn(attr(name: name)) ->
        name
      end)
      {name, attrs}
    end)
  end

  def extract_pcdata(model) do
    model
    |> elem(1)
    |> Enum.reduce([], fn
      (type(name: name, els: [el(alts: [alt(type: {:"#PCDATA", :char})])]), acc) ->
        [name | acc]
      (_t, acc) ->
        acc
    end)
  end

  def extract_empty(module) do
    module
    |> elem(1)
    |> Enum.reduce(MapSet.new(), fn
      (type(name: name, els: []), acc) ->
        MapSet.put(acc, name)
      (_, acc) ->
        acc
    end)
  end

  defp fix_name(name) when is_atom(name) do
    name
    |> Atom.to_string()
    |> String.replace("-", "/")
    |> String.to_atom()
  end
  defp fix_name(name) do
    name
  end

  def format_attr(:undefined) do
    nil
  end
  def format_attr(list) when is_list(list) do
    to_string(list)
  end
  def format_attr(value) do
    value
  end

  def format_children(:undefined, _) do
    []
  end
  def format_children(children, true) do
    [to_string(children)]
  end
  def format_children(child, _) when is_number(child) do
    [child]
  end
  def format_children(children, _) do
    children
  end

  # TODO put these in an error struct
  def format_error('Malformed: Tags don\'t match') do
    ArgumentError
  end
  def format_error('Malformed: Illegal character in tag') do
    ArgumentError
  end
  def format_error('Malformed: Unexpected end of data') do
    ArgumentError
  end
  def format_error('Malformed: Illegal character in prolog') do
    ArgumentError
  end
  def format_error('Malformed: Illegal character in literal value') do
    ArgumentError
  end
  def format_error([{:exception, {:error, {[code | _]}}} | _]) when code in [?1, ?2] do
    # END_TAG
    ArgumentError
  end
  def format_error([{:exception, {:error, 'Unexpected attribute: ' ++ _name}} | _]) do
    ArgumentError
  end
  def format_error([{:exception, {:error, 'Wrong Type in value for attribute ' ++ _name}} | _]) do
    ArgumentError
  end
  def format_error(other) do
    IO.inspect other
    ArgumentError
  end

  defmacro __before_compile__(_) do
    quote unquote: false do
      import EXSD.Schema

      {:ok, model} = :erlsom.compile_xsd(@xsd, [value_fun: &__MODULE__.format_element/2])
      @model model

      elements = extract_element_names(model)
      pcdata = extract_pcdata(model)
      empty = extract_empty(model)

      for {name, attrs} <- extract_attr_names(model) do
        wild = Macro.var(:_, nil)
        children_v = Macro.var(:children, nil)
        attr_vars = Enum.map(attrs, &Macro.var(&1, nil))
        attr_format = Enum.map(attrs, fn(attr) ->
          attr = Macro.var(attr, nil)
          quote do
            var!(unquote(attr)) = format_attr(var!(unquote(attr)))
          end
        end)
        attr_map = {:%{}, [], Enum.map(attrs, &{&1, Macro.var(&1, nil)})}

        formatted_name = elements[name]

        if MapSet.member?(empty, name) do
          from = {:{}, [], [name, wild | attr_vars]}
          to = {:{}, [], [formatted_name, attr_map, []]}

          def format_element(unquote(from), _acc) do
            unquote_splicing(attr_format)
            to = unquote(to)
            {to, to}
          end
        else
          from = {:{}, [], [name, wild | attr_vars] ++ [children_v]}
          to = {:{}, [], [formatted_name, attr_map, children_v]}
          is_pcdata = name in pcdata

          def format_element(unquote(from), _acc) do
            unquote_splicing(attr_format)
            unquote(children_v) =
              format_children(unquote(children_v), unquote(is_pcdata))
            to = unquote(to)
            {to, to}
          end
        end
      end
      def format_element(other, _) do
        IO.inspect other
        raise ArgumentError
      end

      def parse(xml) do
        case :erlsom.parse(xml, @model) do
          {:error, error} ->
            {:error, format_error(error)}
          other ->
            other
        end
      end

      def parse!(xml) do
        case parse(xml) do
          {:ok, doc} ->
            doc
          {:error, error} ->
            raise error
        end
      end
    end
  end
end
