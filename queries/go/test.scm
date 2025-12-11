((call_expression
  function: (identifier) @func_name
  arguments: (argument_list . (interpreted_string_literal) @test.name))
  (#any-of? @func_name
    "It" "FIt" "PIt" "XIt"
    "Specify" "FSpecify" "PSpecify" "XSpecify"
  )) @test.definition

((call_expression
  function: (identifier) @func_name
  arguments: (argument_list . (interpreted_string_literal) @test.name))
  (#any-of? @func_name
    "Entry" "FEntry" "PEntry" "XEntry"
  )) @test.definition
