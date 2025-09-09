defmodule MetricsEngine.TagKey do
  @moduledoc false

  @sep "|"

  @doc """
  Normalize tags map into canonical ordered key string.
  Empty map becomes "∅".
  """
  @spec from_map(map()) :: String.t()
  def from_map(tags) when tags == %{}, do: "∅"
  def from_map(tags) when is_map(tags) do
    tags
    |> Enum.map(fn {k,v} -> {to_string(k), to_string(v)} end)
    |> Enum.sort()
    |> Enum.map_join(@sep, fn {k,v} -> k <> "=" <> v end)
  end

  @doc """
  Normalize arbitrary tag inputs (atoms/strings) into a map with string keys/values.
  """
  @spec normalize_tags(map()) :: map()
  def normalize_tags(tags) do
    tags
    |> Enum.into(%{}, fn {k,v} -> {to_string(k), to_string(v)} end)
  end

  @doc """
  Returns true if the candidate tag key string represents a superset of filter tags.
  """
  @spec superset_key?(String.t(), map()) :: boolean()
  def superset_key?(_key, filter) when filter == %{}, do: true
  def superset_key?(key, filter) do
    fm = normalize_tags(filter)
    km =
      if key == "∅" do
        %{}
      else
        key
        |> String.split(@sep)
        |> Enum.map(fn kv ->
          case String.split(kv, "=", parts: 2) do
            [k,v] -> {k,v}
            _ -> nil
          end
        end)
        |> Enum.reject(&is_nil/1)
        |> Enum.into(%{})
      end

    Enum.all?(fm, fn {k,v} -> Map.get(km, k) == v end)
  end
end
