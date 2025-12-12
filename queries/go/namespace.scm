((call_expression
  function: (identifier) @func_name
  arguments: (argument_list . (interpreted_string_literal) @namespace.name))
  (#any-of? @func_name
    "Describe" "FDescribe" "PDescribe" "XDescribe"
    "Context" "FContext" "PContext" "XContext"
    "When" "FWhen" "PWhen" "XWhen"
    "DescribeTable" "FDescribeTable" "PDescribeTable" "XDescribeTable"
    "DescribeTableSubtree" "FDescribeTableSubtree" "PDescribeTableSubtree" "XDescribeTableSubtree"
  )) @namespace.definition
