defmodule Gettext.Fuzzy do
  @moduledoc false

  alias Gettext.PO
  alias Gettext.PO.Translation
  alias Gettext.PO.PluralTranslation

  @type translation_key :: binary | {binary, binary}

  @doc """
  Returns a matcher function that takes two translation keys and checks if they
  match.

  `String.jaro_distance/2` (which calculates the Jaro distance) is used to
  measure the distance between the two translations. `threshold` is the minimum
  distance that means a match. `{:match, distance}` is returned in case of a
  match, `:nomatch` otherwise.
  """
  @spec matcher(0..1) :: (translation_key, translation_key -> {:match, 0..1} | :nomatch)
  def matcher(threshold) do
    fn(old_key, new_key) ->
      distance = jaro_distance(old_key, new_key)
      if distance >= threshold, do: {:match, distance}, else: :nomatch
    end
  end

  @doc """
  Finds the Jaro distance between the msgids of two translations.

  To mimic the behaviour of the `msgmerge` tool, this function only calculates
  the Jaro distance of the msgids of the two translations, even if one (or both)
  of them is a plural translation.
  """
  @spec jaro_distance(translation_key, translation_key) :: 0..1
  def jaro_distance(key1, key2)

  # Apparently, msgmerge only looks at the msgid when performing fuzzy
  # matching. This means that if we have two plural translations with similar
  # msgids but very different msgid_plurals, they'll still fuzzy match.
  def jaro_distance(k1, k2) when is_binary(k1) and is_binary(k2), do: String.jaro_distance(k1, k2)
  def jaro_distance({k1, _}, k2) when is_binary(k2),              do: String.jaro_distance(k1, k2)
  def jaro_distance(k1, {k2, _}) when is_binary(k1),              do: String.jaro_distance(k1, k2)
  def jaro_distance({k1, _}, {k2, _}),                            do: String.jaro_distance(k1, k2)

  @doc """
  Merges a translation with the corresponding fuzzy match.

  `new` is the newest translation and `existing` is the existing translation
  that we use to populate the msgstr of the newest translation.
  """
  @spec merge(PO.Translation.t, PO.translation) :: PO.Translation.t
  @spec merge(PO.PluralTranslation.t, PO.translation) :: PO.PluralTranslation.t
  def merge(new, existing) do
    new |> do_merge_fuzzy(existing) |> PO.Translations.mark_as_fuzzy
  end

  defp do_merge_fuzzy(%Translation{} = new, %Translation{} = existing),
    do: %{new | msgstr: existing.msgstr}
  defp do_merge_fuzzy(%Translation{} = new, %PluralTranslation{} = existing),
    do: %{new | msgstr: existing.msgstr[0]}
  defp do_merge_fuzzy(%PluralTranslation{} = new, %Translation{} = existing),
    do: %{new | msgstr: (for {i, _} <- new.msgstr, into: %{}, do: {i, existing.msgstr})}
  defp do_merge_fuzzy(%PluralTranslation{} = new, %PluralTranslation{} = existing),
    do: %{new | msgstr: existing.msgstr}
end
