-- STOP HITTING EACH OTHER MOD
meta = {
  name = "Stop hitting each other",
  version = "0.1",
  description = "No friendly or self damage",
  author = "Quasar",
}

---@param uid integer
---@return boolean
local function is_player(uid)
  for _, player in ipairs(get_local_players()) do
    if player.uid == uid then
      return true
    end
  end
  return false
end

---@param entity_type ENT_TYPE
---@return boolean
local function is_exmplosion(entity_type)
  return entity_type == ENT_TYPE.FX_EXPLOSION
      or entity_type == ENT_TYPE.FX_POWEREDEXPLOSION
      or entity_type == ENT_TYPE.FX_MODERNEXPLOSION
end

---@param victim Movable
---@param attacker Movable
---@param damage_amount integer
---@param damage_flags DAMAGE_TYPE
---@param velocity Vec2
---@param unknown_damage_phase integer
---@param stun_amount integer
---@param iframes integer
---@param unknown_is_final boolean
---@return boolean?
local function on_pre_damage(
    victim, attacker, damage_amount, damage_flags,
    velocity, unknown_damage_phase, stun_amount,
    iframes, unknown_is_final)
  if attacker == nil then
    return nil -- allow damage from environment
  end

  if is_player(victim.uid) then
    if is_player(attacker.uid) then
      return false
    end

    if is_player(attacker.last_owner_uid) then
      ---@diagnostic disable-next-line unknowd_field
      if attacker.shot_from_trap then
        return nil -- arrows shot from traps hurt
      end

      if is_exmplosion(attacker.type.id) then
        return nil -- explosions from player caused explosions hurt
      end

      return false
    end
  end

  return nil
end

---@param self Movable
---@param entity Entity
local function on_post_pickup(self, entity)
  if entity.shot_from_trap == nil then
    return
  end

  ---@cast entity Arrow
  entity.shot_from_trap = not is_player(self.uid)
end

set_post_entity_spawn(function(entity, spawn_flags)
  ---@diagnostic disable-next-line unknowd_field
  if entity.set_pre_damage == nil then
    return
  end

  ---@cast entity Movable
  entity:set_pre_damage(on_pre_damage)
  entity:set_post_pick_up(on_post_pickup)
end, SPAWN_TYPE.ANY, MASK.ANY)
