-- STOP HITTING EACH OTHER MOD
meta = {
  name = "Stop hitting each other",
  version = "0.1",
  description = "No friendly or self damage",
  author = "Quasar",
}

-- ==============================================================================

---@param entity Entity
---@return boolean
local function is_player(entity)
  ---@diagnostic disable-next-line undefined-field
  return entity.get_short_name ~= nil
end

---@param entity Entity
---@return boolean
local function is_pet(entity)
  ---@diagnostic disable-next-line undefined-field
  return entity.petted_counter ~= nil
end

---@param entity Entity
---@return boolean
local function is_mount(entity)
  ---@diagnostic disable-next-line undefined-field
  return entity.tamed ~= nil
end

---@param entity_type ENT_TYPE
---@return boolean
local function is_exmplosion(entity_type)
  return
      entity_type == ENT_TYPE.FX_EXPLOSION
      or entity_type == ENT_TYPE.FX_POWEREDEXPLOSION
      or entity_type == ENT_TYPE.FX_MODERNEXPLOSION
end

-- ==============================================================================

---@param victim Player
---@param attacker Movable
---@return boolean?
local function on_player_pre_damage(victim, attacker)
  if attacker == nil then
    return nil -- allow damage from environment
  end

  if is_player(attacker) then
    return false
  end

  if is_player(get_entity(attacker.last_owner_uid)) then
    ---@diagnostic disable-next-line unknowd_field
    if attacker.shot_from_trap then
      return nil -- arrows shot from traps hurt
    end
    if is_exmplosion(attacker.type.id) then
      return nil -- explosions from player caused explosions hurt
    end
    return false
  end

  return nil
end

---@param victim Pet
---@param attacker Movable
---@return boolean?
local function on_pet_pre_damage(victim, attacker)
  if attacker == nil then
    return nil -- allow damage from environment
  end

  if is_player(attacker) then
    return false
  end

  if is_player(get_entity(attacker.last_owner_uid)) then
    ---@diagnostic disable-next-line unknowd_field
    if attacker.shot_from_trap then
      return nil -- arrows shot from traps hurt
    end
    if is_exmplosion(attacker.type.id) then
      return nil -- explosions from player caused explosions hurt
    end
    return false
  end

  return nil
end

---@param victim Mount
---@param attacker Movable
---@return boolean?
local function on_mount_pre_damage(victim, attacker)
  if attacker == nil then
    return nil -- allow damage from environment
  end

  if victim.tamed then
    if is_player(attacker) then
      return false
    end

    if is_player(get_entity(attacker.last_owner_uid)) then
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
  entity.shot_from_trap = not is_player(self)
end

---@param entity Entity
local function on_spawn(entity)
  ---@diagnostic disable-next-line unknowd_field
  if entity.set_pre_damage == nil then
    return
  end
  ---@cast entity Movable
  entity:set_post_pick_up(on_post_pickup)

  if is_player(entity) then
    entity:set_pre_damage(on_player_pre_damage)
  elseif options.spare_pets and is_pet(entity) then
    entity:set_pre_damage(on_pet_pre_damage)
  elseif options.spare_mounts and is_mount(entity) then
    entity:set_pre_damage(on_mount_pre_damage)
  end
end

-- ==============================================================================

register_option_bool(
  "spare_pets",
  "Players can't damage pets",
  true
)

register_option_bool(
  "spare_mounts",
  "Players can't damage tamed mounts",
  true
)

set_post_entity_spawn(on_spawn, SPAWN_TYPE.ANY, MASK.ANY)
