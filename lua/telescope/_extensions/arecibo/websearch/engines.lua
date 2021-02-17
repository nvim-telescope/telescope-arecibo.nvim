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

 return engines
