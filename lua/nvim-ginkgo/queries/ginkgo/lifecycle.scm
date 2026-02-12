; Ginkgo lifecycle hooks
; BeforeEach, AfterEach, etc. do not have description strings
; Report* variants have description strings

; Lifecycle hooks without description strings
((call_expression
  function: (identifier) @func_name
  arguments: (argument_list))
  (#any-of? @func_name
    "BeforeEach" "AfterEach" "JustBeforeEach" "JustAfterEach"
    "BeforeSuite" "AfterSuite"
  )) @lifecycle.definition

; Reporting hooks with description strings (optional first argument)
((call_expression
  function: (identifier) @func_name
  arguments: (argument_list))
  (#any-of? @func_name
    "ReportBeforeEach" "ReportAfterEach" "ReportBeforeSuite" "ReportAfterSuite"
  )) @lifecycle.definition
