; Ginkgo test nodes: It, Specify, Entry
; These nodes represent individual test cases

((call_expression
  function: (identifier) @func_name
  arguments: (argument_list . (interpreted_string_literal) @test.name))
  (#any-of? @func_name
    "It" "FIt" "PIt" "XIt"
    "Specify" "FSpecify" "PSpecify" "XSpecify"
  )) @test.definition
