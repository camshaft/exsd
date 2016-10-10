defmodule EXSD.Type do
  defmacro __using__(_) do
    quote do
      alias EXSD.Type.{ComplexType,Ref,SimpleType,UnionType}
    end
  end

  defmodule ComplexType do
    defstruct [:name, :props, :children]
  end

  defmodule Ref do
    defstruct [:name]
  end

  defmodule SimpleType do
    defstruct [:type]
  end

  defmodule UnionType do
    defstruct [:head, :tail]
  end
end
