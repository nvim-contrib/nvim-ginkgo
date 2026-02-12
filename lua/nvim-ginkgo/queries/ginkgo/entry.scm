; Ginkgo table test entries
; Entry nodes used with DescribeTable and DescribeTableSubtree

((call_expression
  function: (identifier) @func_name
  arguments: (argument_list . (interpreted_string_literal) @entry.name))
  (#any-of? @func_name "Entry" "FEntry" "PEntry" "XEntry"))
  @entry.definition
