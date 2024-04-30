local Rectangle = {}

---@alias Rectangle { x: number, y: number, width: number, height: number }

---@param rect Rectangle
---@param point { x: number, y: number }
function Rectangle.contains_point(rect, point)
  return (
    point.x >= rect.x and
    point.x <= rect.x + rect.width and
    point.y >= rect.y and
    point.y <= rect.y + rect.height
  )
end

return Rectangle
