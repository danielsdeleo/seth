module cethSpecs
  class TestExplicitCategory < Seth::ceth
    # i.e., the cookbook site commands should be in the cookbook site
    # category instead of cookbook (which is what would be assumed)
    category "cookbook site"
  end
end
