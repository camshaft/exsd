defmodule EXSD.Compiler do
  use EXSD.Type

  defmacro __using__(_) do
    quote do
      import unquote(__MODULE__)
      @path_list []
      @tags %{}
      @before_compile unquote(__MODULE__)
    end
  end

  defmacro __before_compile__(_) do
    quote unquote: false do
      tags = @tags
      entry = @entry

      defp transform(charlist, _) when is_list(charlist) do
        :erlang.list_to_binary(charlist)
      end
      defp transform(child, _) when not is_tuple(child) do
        child
      end

      case Map.fetch(tags, entry) do
        :error ->
          throw {:missing_entry}
        _ ->
          :ok
      end

      xsd = EXSD.XML.to_schema(tags, entry)

      defmodule Schema do
        @moduledoc false
        use EXSD.Schema, xsd: xsd
      end

      @doc """

      """
      def schema() do
        unquote(xsd)
      end

      def parse(xml) do
        xml
        |> Schema.parse()
        |> transform([])
      end

      def parse!(xml) do
        xml
        |> Schema.parse!()
        |> transform([])
      end
    end
  end

  types = [
    :string,
    :uri,
    :boolean,
    :number,
    :integer,
    :float
  ]

  for type <- types do
    map = %SimpleType{type: type} |> Macro.escape()
    defmacro unquote(type)() do
      unquote(Macro.escape(map))
    end
    defp to_type(unquote(type)) do
      unquote(map)
    end
  end

  defmacro defentry(name, url) do
    name = case name do
      {name, _, _} ->
        name
      name when is_atom(name) ->
        name
    end
    module = __CALLER__.module
    quote do
      require Multix
      Multix.defdispatch EXSD.Locator, for: unquote(url) do
        def locate(_) do
          unquote(module)
        end
      end

      @entry unquote(name)
    end
  end

  defmacro defel(name) do
    compile_el(name, [do: []])
  end

  defmacro defel(name, children) do
    compile_el(name, children)
  end

  defmacro defel(name, props, children) do
    compile_el({name, [], [props]}, children)
  end

  defmacro ref({name, _, args}) when args in [nil, []] do
    %Ref{name: name}
    |> Macro.escape()
  end

  defp compile_el(name, block) when is_atom(name) do
    compile_el({name, [], nil}, block)
  end
  defp compile_el({name, meta, args}, block) when args in [nil, []] do
    compile_el({name, meta, [[]]}, block)
  end
  defp compile_el(name, type) when is_tuple(type) do
    compile_el(name, [do: type])
  end
  defp compile_el({name, _, [props]}, [do: children]) do
    {prop_types, match, assign} = format_props(props, [], [], [])

    children = quote do
      prev = @path_list
      @path_list [unquote(to_string(name)) | prev]
      children = unquote(format_children(children))
      @path_list prev
      children
    end

    quote bind_quoted: [name: name,
                        children: children,
                        prop_types: Macro.escape(prop_types),
                        match: Macro.escape(match),
                        assign: Macro.escape(assign)], location: :keep do
      path_list = @path_list

      struct_name = name
      |> to_string()
      |> String.replace("-", "_")

      struct_path = [struct_name | path_list] |> :lists.reverse()

      struct = [__MODULE__ | Enum.map(struct_path, &Macro.camelize/1)] |> Module.concat()
      defmodule struct do
        defstruct [meta: %{}, path: [], props: %{}, children: []]

        defimpl Inspect do
          import Inspect.Algebra

          @print_name inspect(@for)
          def inspect(%{props: props, children: children}, opts) do
            name = @print_name
            concat([
              "##{name}<", concat([
                to_doc(props, opts),
                ">",
                line(
                  Enum.reduce(children, break(), fn(child, parent) ->
                    glue(
                      parent,
                      nest(line(break(), to_doc(child, opts)), 2)
                    )
                  end),
                  "##{name}</>"
                )
              ])
            ])
          end
        end
      end

      tag = [to_string(name) | path_list]
      |> :lists.reverse()
      |> Enum.join("/")
      |> String.to_atom()
      defp transform({unquote(tag), %{unquote_splicing(match)}, children}, path) do
        %unquote(struct){
          path: :lists.reverse(path),
          props: %{unquote_splicing(assign)},
          children:
            children
            |> Stream.with_index()
            |> Enum.map(fn({child, idx}) ->
              transform(child, [idx | path])
            end)
        }
      end

      t = %EXSD.Type.ComplexType{
        name: name,
        props: prop_types,
        children: children
      }

      @tags Map.put(@tags, tag, t)

      t
    end
  end

  defp format_props([], types, match, assign) do
    {:lists.reverse(types), :lists.reverse(match), :lists.reverse(assign)}
  end
  defp format_props([{name, spec} | rest], types, match, assign) do
    {type, default} = format_spec(spec)
    var = Macro.var(name, nil)
    types = [{name, type} | types]
    match = [{name, var} | match]
    assign = [{name, assign_default(var, default)} | assign]
    format_props(rest, types, match, assign)
  end

  defp assign_default(var, nil) do
    var
  end
  defp assign_default(var, default) do
    quote do
      case unquote(var) do
        nil ->
          unquote(default)
        value ->
          value
      end
    end
  end

  defp format_spec({:|, _, [head, tail]}) do
    {head_t, _} = format_spec(head)
    {tail_t, default} = format_spec(tail)
    {
      %UnionType{head: head_t, tail: tail_t},
      default
    }
  end
  defp format_spec({:=, _, [spec, default]}) do
    {type, nil} = format_spec(spec)
    {
      type,
      default
    }
  end
  defp format_spec(value) when is_binary(value) do
    {
      :string,
      nil
    }
  end
  defp format_spec({name, _, nil}) do
    {
      to_type(name),
      nil
    }
  end

  defp format_children({:__block__, _, children}) do
    children
  end
  defp format_children(child) when is_tuple(child) do
    [child]
  end
  defp format_children(child) when child in [nil, []] do
    []
  end
end
