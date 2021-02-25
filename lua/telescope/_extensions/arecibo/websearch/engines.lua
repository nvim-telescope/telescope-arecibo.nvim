local engines = {}

engines.google = {
  name = 'Google',
  host = 'www.google.com',
  port = 443,
  query_template = '/search?q=%s&num=30',
  ts_query =
[[
(element
  (element
    . (_)*
    (element
      . (start_tag
          (attribute
            . (attribute_name) @href (eq? @href "href")
            (_
              (attribute_value) @url
            )
          )
        )
    . (element
      . (start_tag (tag_name) @header (#eq? @header "h3"))
      . (_)*
      .  (element
          (start_tag)
          . (text) @title
        )
      )
    )
  )
)
]]
}

engines.duckduckgo = {
  name = 'DuckDuckGo',
  host = 'html.duckduckgo.com',
  port = 443,
  query_template = '/html/?q=%s',
  ts_query =
[[
(element
  (start_tag
    (tag_name) @_parent
    (#eq? @_parent "div"))
  (element
    (start_tag
      (tag_name) @_heading)
      (#eq? @_heading "h2")
    (element
      (start_tag
        (attribute
          (attribute_name) @_href
          (#eq? @_href "href")
          (quoted_attribute_value
            (attribute_value) @url)))
      (text) @title)))
]]
}

engines.npmjs = {
  name = 'NPMJS',
  host = 'www.npmjs.com',
  port = 443,
  query_template = '/search?q=%s',
  ts_query =
[[
(element
  (start_tag
    (tag_name) @_parent
     (#eq? @_parent "section"))
  (element
    (element
      (element
        (start_tag
          (tag_name) @_url-tag
          (#eq? @_url-tag "a")
          (attribute
            (attribute_name) @_href-attr
            (#eq? @_href-attr "href")
            (quoted_attribute_value
              (attribute_value) @url)))
        (element
          (start_tag
            (tag_name) @_heading-tag
            (#eq? @_heading-tag "h3"))
          (text) @title )))))
]]
}

 return engines
