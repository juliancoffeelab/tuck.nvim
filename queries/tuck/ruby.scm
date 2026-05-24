; Method definitions
(method
  body: (body_statement) @fold) @owner

; Singleton method definitions (def self.foo)
(singleton_method
  body: (body_statement) @fold) @owner
