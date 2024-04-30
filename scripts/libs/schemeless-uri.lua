local exports = {}

--- `"website.com:1234/data"` -> `"website.com"`
exports.get_host = function(text)
  local end_index = string.find(text, "[:/?#]") or (#text + 1)

  return string.sub(text, 1, end_index - 1)
end

--- `"website.com:1234/data"` -> `1234`
exports.get_port = function(text)
  local port_start = string.find(text, ":")

  if not port_start then return end

  local port_end = string.find(text, "[/?#]", port_start) or (#text + 1)

  return tonumber(string.sub(text, port_start + 1, port_end - 1))
end

--- Resolves the path, fragment, and search/query part of the URI.
---
--- `"website.com:1234/path?a=b#fragment"` -> `"/data?a=b#fragment"`
exports.get_data = function(text)
  local data_index = string.find(text, "[/?#]") or (#text + 1)

  return string.sub(text, data_index, #text)
end

--- Resolves the path part of the URI.
---
--- `"website.com:1234/path?a=b#fragment"` -> `"/path"`
exports.get_path = function(text)
  local path_index = string.find(text, "/")

  if not path_index then
    return
  end

  local end_index = string.find(text, "[#?]") or (#text + 1)

  return string.sub(text, path_index, end_index - 1)
end

--- Resolves the search/query part of the URI
---
--- `"website.com:1234/path?a=b#fragment"` -> `"a=b"`
exports.get_query = function(text)
  local query_index = string.find(text, "?")

  if not query_index then
    return
  end

  local end_index = string.find(text, "#") or (#text + 1)

  return string.sub(text, query_index + 1, end_index - 1)
end

--- Resolves the fragment part of the URI.
---
--- `"website.com:1234/path?a=b#fragment"` -> `"fragment"`
exports.get_fragment = function(text)
  local fragment_index = string.find(text, "#")

  if not fragment_index then
    return
  end

  return string.sub(text, fragment_index + 1, #text)
end


--- Returns an iterator function which parses the query string on the fly.
--- A single key and value will be returned on each iteration.
--- ```lua
--- local URI = require("scripts/libs/schemeless-uri")
---
--- for key, value in URI.iterate_query("a=1&b=2") do
---   print(key, value)
--- end
--- ```
--- The example above will print `a 1` then `b 2`
exports.iterate_query = function(text)
  local last_index = 0

  return function()
    if last_index >= #text then
      return
    end

    local eq_index = string.find(text, "=", last_index)
    local amp_index = string.find(text, "&", eq_index)

    if amp_index == nil then
      amp_index = #text + 1
    end

    local key = string.sub(text, last_index, eq_index - 1)
    local encoded_value = string.sub(text, eq_index + 1, amp_index - 1)

    last_index = amp_index + 1

    return key, encoded_value
  end
end

--- Parses a query string into a table.
--- ```lua
--- local URI = require("scripts/libs/schemeless-uri")
---
--- local query = URI.parse_query("a=1&b=c") -- { a = "1", b = "c" }
--- print(query.a) -- 1
--- print(query.b) -- c
--- ```
exports.parse_query = function(text)
  local result = {}

  for key, value in exports.iterate_query(text) do
    result[key] = value
  end

  return result
end

return exports
