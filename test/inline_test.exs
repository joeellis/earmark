defmodule InlineTest do
  use ExUnit.Case

  alias Earmark.Inline
  alias Earmark.Block.IdDef

  ###############
  # Helpers.... #
  ###############

  def context do
    %Earmark.Context{}
  end

  def test_links do
    [
     {"id1", %IdDef{url: "url 1", title: "title 1"}},
     {"id2", %IdDef{url: "url 2"}},

     {"img1", %IdDef{url: "img 1", title: "image 1"}},
     {"img2", %IdDef{url: "img 2"}},
    ]
    |> Enum.into(HashDict.new)
  end

  def pedantic_context do
    ctx = put_in(context.options.gfm, false)
    ctx = put_in(ctx.options.pedantic, true)
    ctx = put_in(ctx.links, test_links)
    Inline.update_context(ctx)
  end

  def gfm_context do
    Inline.update_context(context)
  end

  def convert_pedantic(string) do
    Inline.convert(string, pedantic_context)
  end

  def convert_gfm(string) do
    Inline.convert(string, gfm_context)
  end

  ############################################################
  # Tests                                                    #
  ############################################################

  test "smoke" do
    result = convert_pedantic("hello")
    assert result == "hello"
  end

  test "line ending with 2 spaces causes a <br/>" do
    result = convert_pedantic("hello  \nworld")
    assert result == "hello<br/>world"
  end

  ################
  # Kanji / Kana #
  ################

  test "compound kanji plus kana" do
    result = convert_gfm("{東}(とう){京}(きょう)")
    assert result == "<ruby>東<rt>とう</rt></ruby><ruby>京<rt>きょう</rt></ruby>"
  end

  test "single kanji plus kana" do
    result = convert_gfm("{東}(とう)")
    assert result == "<ruby>東<rt>とう</rt></ruby>"
  end

  test "double kanji plus kana" do
    result = convert_gfm("{東京}(とうきょう)")
    assert result == "<ruby>東京<rt>とうきょう</rt></ruby>"
  end

  test "double kanji plus kana" do
    result = convert_gfm("{東京}(とうきょう)")
    assert result == "<ruby>東京<rt>とうきょう</rt></ruby>"
  end

  test "double kanji plus kana" do
    result = convert_gfm("test {東京}(とうきょう)")
    assert result == "test <ruby>東京<rt>とうきょう</rt></ruby>"
  end

  test "many kanji combinations" do
    result = convert_gfm("{今}(いま)、サマーキャンプで{子}(こ){供}(ども){達}(たち)")
    assert result == "<ruby>今<rt>いま</rt></ruby>、サマーキャンプで<ruby>子<rt>こ</rt></ruby><ruby>供<rt>ども</rt></ruby><ruby>達<rt>たち</rt></ruby>"
  end

  ############
  # Emphasis #
  ############

  test "asterisk means <em>" do
    result = convert_pedantic("hello *world*")
    assert result == "hello <em>world</em>"
  end

  test "underscore means <em>" do
    result = convert_pedantic("hello _world_")
    assert result == "hello <em>world</em>"
  end

  test "double asterisk means <strong>" do
    result = convert_pedantic("hello **world**")
    assert result == "hello <strong>world</strong>"
  end

  test "double underscore means <strong>" do
    result = convert_pedantic("hello __world__")
    assert result == "hello <strong>world</strong>"
  end

  test "emphasis works inside words" do
    result = convert_pedantic("un*frigging*believable")
    assert result == "un<em>frigging</em>believable"
  end

  test "asterisks surrounded by spaces are not emphasis in pedantic mode" do
    result = convert_pedantic("un * frigging * believable")
    assert result == "un * frigging * believable"
  end

  test "asterisks surrounded by spaces are emphasis in gfm mode" do
    result = convert_gfm("un * frigging * believable")
    assert result == "un <em> frigging </em> believable"
  end

  test "backslashes stop asterisks being significant" do
    result = convert_pedantic("hello \\*world\\*")
    assert result == "hello *world*"
  end

  test "tilde mean strikethrough" do
    result = convert_gfm("this ~~not this~~")
    assert result == "this <del>not this</del>"
  end

  ########
  # Code #
  ########

  test "backticks mean code" do
    result = convert_pedantic("the `printf` function")
    assert result == ~s[the <code class="inline">printf</code> function]
  end

  test "literal backticks can be included within doubled backticks" do
    result = convert_pedantic("``the ` character``")
    assert result == ~s[<code class="inline">the ` character</code>]
  end

  test "a space after the opening and before the closing doubled backticks are ignored" do
    result = convert_pedantic("`` the ` character``")
    assert result == ~s[<code class="inline">the ` character</code>]
  end

  test "single backtick with spaces inside doubled backticks" do
    result = convert_pedantic("`` ` ``")
    assert result == ~s[<code class="inline">`</code>]
  end

  test "ampersands and angle brackets are escaped in code" do
    result = convert_pedantic("the `<a> &123;` function")
    expect =
      ~s[the <code class="inline">&lt;a&gt; &amp;123;</code> function]
    assert result == expect
  end

  #################
  # Inline images #
  #################

  test "inline image tag" do
    result = convert_pedantic("the ![image](/path.jpg) tag")
    assert result == ~S[the <img src="/path.jpg" alt="image"/> tag]
  end

  test "inline image tag with a title" do
    result = convert_pedantic(~s<the ![image](/path.jpg "a title") tag>)
    assert result == ~S[the <img src="/path.jpg" alt="image" title="a title"/> tag]
  end

  ###################
  # Automatic links #
  ###################
  test "automatic links" do
    result = convert_pedantic("a <http://google.com> link")
    assert result == ~s[a <a href="http://google.com">http://google.com</a> link]
  end

  test "email link" do
    result = convert_pedantic("a <dave@google.com> link")
    assert result == ~s[a <a href="mailto:dave@google.com">dave@google.com</a> link]
  end

  ################
  # Inline links #
  ################

  test "basic inline link" do
    result = convert_pedantic(~s{a [an example](http://example.com/ "Title") link})
    assert result == ~s[a <a href="http://example.com/" title="Title">an example</a> link]
  end

  test "basic inline link with title in single quotes" do
    result = convert_pedantic(~s{a [an example](http://example.com/ 'Title') link})
    assert result == ~s[a <a href="http://example.com/" title="Title">an example</a> link]
  end

  test "link with no title" do
    result = convert_pedantic(~s{a [an example](http://example.com/) link})
    assert result == ~s[a <a href="http://example.com/">an example</a> link]
  end

  ###################
  # Reference links #
  ###################

  test "basic reference link" do
    result = convert_pedantic(~s{a [my link][id1] link})
    assert result == ~s[a <a href=\"url 1\" title=\"title 1\">my link</a> link]
  end

  test "case insensitive reference link" do
    result = convert_pedantic(~s{a [my link][ID1] link})
    assert result == ~s[a <a href=\"url 1\" title=\"title 1\">my link</a> link]
  end

  test "basic reference link with no title" do
    result = convert_pedantic(~s{a [my link][id2] link})
    assert result == ~s[a <a href=\"url 2\">my link</a> link]
  end

  test "basic reference link with a space inside" do
    result = convert_pedantic(~s{a [mylink]  [id1] link})
    assert result == ~s[a <a href=\"url 1\" title=\"title 1\">mylink</a> link]
  end

  test "shorthand reference link" do
    result = convert_pedantic(~s{a [id1][] link})
    assert result == ~s[a <a href=\"url 1\" title=\"title 1\">id1</a> link]
  end


  #########################
  # Reference image links #
  #########################

  test "basic reference image link" do
    result = convert_pedantic(~s{a ![my image][img1] link})
    assert result ==
      ~s[a <img src="img 1" alt="my image" title="image 1"/> link]
  end

  test "basic reference image link with no title" do
    result = convert_pedantic(~s{a ![my image][img2] link})
    assert result ==
      ~s[a <img src="img 2" alt="my image"/> link]
  end


  ###############
  # Inline HTML #
  ###############

  test "inline HTML" do
    result = convert_pedantic(~s[a <span class="red">a&b</span> color])
    assert result == ~s[a <span class="red">a&amp;b</span> color]
  end
end
