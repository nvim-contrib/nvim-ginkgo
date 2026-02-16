; Ginkgo namespace nodes: Describe, Context, When, DescribeTable, DescribeTableSubtree
; These nodes create test containers/hierarchies

((call_expression
  function: (identifier) @func_name
  arguments: (argument_list . (interpreted_string_literal) @namespace.name))
  (#any-of? @func_name
    "Describe" "FDescribe" "PDescribe" "XDescribe"
    "DescribeTable" "FDescribeTable" "PDescribeTable" "XDescribeTable"
    "Context" "FContext" "PContext" "XContext"
    "When" "FWhen" "PWhen" "XWhen"
  )) @namespace.definition
