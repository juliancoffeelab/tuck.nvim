; Function definitions
(function_definition
  body: (compound_statement) @fold) @owner

; Method declarations in classes
(method_declaration
  body: (compound_statement) @fold) @owner
