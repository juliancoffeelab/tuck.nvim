; Top-level function bodies
(function_declaration
  body: (block) @fold) @owner

; Method definitions in tables (common Lua pattern)
(field
  value: (function_definition
    body: (block) @fold)) @owner
