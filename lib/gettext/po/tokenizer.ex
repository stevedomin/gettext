defmodule Gettext.PO.Tokenizer do
  @moduledoc false

  # This module is responsible for turning a chunk of text (a string) into a
  # list of tokens. For what "token" means, see the docs for `tokenize/1`.

  @type token ::
    {:str, pos_integer, binary} |
    {:msgid, pos_integer} |
    {:msgstr, pos_integer}

  alias Gettext.PO.SyntaxError
  alias Gettext.PO.TokenMissingError

  @keywords ~w(msgid msgstr)

  @whitespace [?\n, ?\t, ?\r, ?\s]
  @whitespace_no_nl [?\t, ?\r, ?\s]
  @escapable_chars [?", ?n, ?t, ?\\]

  @doc """
  Converts a string into a list of tokens.

  A "token" is a tuple formed by:

    * the `:str` tag or a keyword tag (like `:msgid`)
    * the line the token is at
    * the value of the token if the token has a value (for example, a `:str`
      token will have the contents of the string as a value)

  Some examples of tokens are:

    * `{:msgid, 33}`
    * `{:str, 6, "foo"}`

  """
  @spec tokenize(binary) :: [token]
  def tokenize(str) do
    tokenize_line(str, 1, [])
  end

  # Converts the first line in `str` into a list of tokens and then moves on to
  # the next line.
  @spec tokenize_line(binary, pos_integer, [token]) :: [token]
  defp tokenize_line(str, line, acc)

  # End of file.
  defp tokenize_line(<<>>, _line, acc) do
    Enum.reverse acc
  end

  # Go to the next line.
  defp tokenize_line(<<?\n, rest :: binary>>, line, acc) do
    tokenize_line(rest, line + 1, acc)
  end

  # Skip whitespace.
  defp tokenize_line(<<char, rest :: binary>>, line, acc)
      when char in @whitespace_no_nl do
    tokenize_line(rest, line, acc)
  end

  # Comments.
  defp tokenize_line(<<?#, rest :: binary>>, line, acc) do
    {_comment_contents, rest} = to_eol_or_eof(rest, "")
    tokenize_line(rest, line, acc)
  end

  # Keywords.
  for kw <- @keywords do
    defp tokenize_line(unquote(kw) <> <<char, rest :: binary>>, line, acc)
        when char in @whitespace do
      acc = [{unquote(String.to_atom(kw)), line}|acc]
      tokenize_line(rest, line, acc)
    end

    defp tokenize_line(unquote(kw) <> _rest, line, _acc) do
      raise(SyntaxError, message: "no space after '#{unquote(kw)}'", line: line)
    end
  end

  # String start.
  defp tokenize_line(<<?", rest :: binary>>, line, acc) do
    {token, rest} = tokenize_string(rest, line, "")
    tokenize_line(rest, line, [token|acc])
  end

  # Parses the double-quotes-delimited string `str` into a single `{:str,
  # line, contents}` token. Note that `str` doesn't start with a double quote
  # (since that was needed to identify the start of a string). Returns a tuple
  # with the contents of the string and the rest of the original `str` (note
  # that the rest of the original string doesn't include the closing double
  # quote).
  @spec tokenize_string(binary, pos_integer, binary) :: {token, binary}
  defp tokenize_string(str, line, acc)

  defp tokenize_string(<<?", rest :: binary>>, line, acc),
    do: {{:str, line, acc}, rest}
  defp tokenize_string(<<?\\, char, rest :: binary>>, line, acc)
    when char in @escapable_chars,
    do: tokenize_string(rest, line, <<acc :: binary, escape_char(char)>>)
  defp tokenize_string(<<?\\, _char, _rest :: binary>>, line, _acc),
    do: raise(SyntaxError, line: line, message: "unsupported escape code")
  defp tokenize_string(<<?\n, _rest :: binary>>, line, _acc),
    do: raise(SyntaxError, line: line, message: "newline in string")
  defp tokenize_string(<<char, rest :: binary>>, line, acc),
    do: tokenize_string(rest, line, <<acc :: binary, char>>)
  defp tokenize_string(<<>>, line, _acc),
    do: raise(TokenMissingError, line: line, token: ~s("))

  @spec escape_char(char) :: char
  defp escape_char(?n), do: ?\n
  defp escape_char(?t), do: ?\t
  defp escape_char(?r), do: ?\r
  defp escape_char(?"), do: ?"
  defp escape_char(?\\), do: ?\\

  @spec to_eol_or_eof(binary, binary) :: {binary, binary}
  defp to_eol_or_eof(<<?\n, _ :: binary>> = rest, acc),
    do: {acc, rest}
  defp to_eol_or_eof(<<>>, acc),
    do: {acc, ""}
  defp to_eol_or_eof(<<char, rest :: binary>>, acc),
    do: to_eol_or_eof(rest, <<acc :: binary, char>>)
end