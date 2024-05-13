---@class IteratorLib
local IteratorLib = {}

---@generic T
---@param amount number
---@param iter fun(): T?
---@return fun(): T?
function IteratorLib.take(amount, iter)
  return function()
    if amount <= 0 then
      return
    end

    amount = amount - 1
    return iter()
  end
end

function IteratorLib.chain(...)
  local iters = { ... }

  local i = 1
  local iter = iters[i]

  return function()
    while iter do
      local output = iter()

      if output ~= nil then
        return output
      end

      i = i + 1
      iter = iters[i]
    end
  end
end

---@generic T
---@param iter fun(): nil | fun(): T
---@return fun(): T?
function IteratorLib.flatten(iter)
  local inner_iter = iter()

  return function()
    while inner_iter do
      local output = inner_iter()

      if output ~= nil then
        return output
      end

      inner_iter = iter()
    end
  end
end

function IteratorLib.pipeline(iter, ...)
  local operations = { ... }

  for _, op in ipairs(operations) do
    iter = op(iter)
  end

  return iter
end

return IteratorLib
