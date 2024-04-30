local exports = {
  MUG_TEXTURE           = "/server/assets/bots/ampstr_mug.png",
  MUG_ANIMATION         = "/server/assets/bots/ampstr_mug.animation",
  SERIOUS_MUG_TEXTURE   = "/server/assets/bots/ampstr_serious_mug.png",
  SERIOUS_MUG_ANIMATION = "/server/assets/bots/ampstr_serious_mug.animation",
  TEXTURE               = "/server/assets/bots/ampstr.png",
  ANIMATION             = "/server/assets/bots/ampstr.animation",
}

function exports.serious(player_id, callback)
  if math.random(8) ~= 1 then
    return false
  end

  local message = "\u{1}..."
  local texture = exports.SERIOUS_MUG_TEXTURE
  local animation = exports.SERIOUS_MUG_ANIMATION

  if callback then
    Async.message_player(player_id, message, texture, animation)
        .and_then(callback)
  else
    Net.message_player(player_id, message, texture, animation)
  end

  return true
end

function exports.message_player(player_id, message)
  return Net.message_player(
    player_id,
    message,
    exports.MUG_TEXTURE,
    exports.MUG_ANIMATION
  )
end

function exports.message_player_async(player_id, message)
  return Async.message_player(
    player_id,
    message,
    exports.MUG_TEXTURE,
    exports.MUG_ANIMATION
  )
end

function exports.question_player_async(player_id, question)
  return Async.question_player(
    player_id,
    question,
    exports.MUG_TEXTURE,
    exports.MUG_ANIMATION
  )
end

return exports
