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

---@param type ENT_TYPE
---@return boolean
local function is_explosion(type)
  return
      type == ENT_TYPE.FX_EXPLOSION
      or type == ENT_TYPE.FX_POWEREDEXPLOSION
      or type == ENT_TYPE.FX_MODERNEXPLOSION
end

---@param attacker Movable
---@return boolean?
local function should_block_player_damage(attacker)
  if not attacker then
    return nil -- Allow environmental damage (spikes, lava, etc.)
  end

  -- Block direct player damage
  if is_player(attacker) then
    return false
  end

  local owner = get_entity(attacker.last_owner_uid)
  if not is_player(owner) then
    return nil -- Not player-owned, allow damage
  end

  -- Arrows from traps should still hurt
  ---@diagnostic disable-next-line undefined-field
  if attacker.shot_from_trap then
    return nil
  end

  -- Explosions from player actions should still hurt
  if is_explosion(attacker.type.id) then
    return nil
  end

  -- Block all other player-owned damage
  return false
end

-- ==============================================================================

---@param save_context SaveContext
local function save_options(save_context)
  save_context:save(json.encode(options))
end

---@param load_context LoadContext
local function load_options(load_context)
  local options_str = load_context:load()
  if options_str ~= '' then
    options = json.decode(options_str)
  end
end

---@param attacker Movable
---@return boolean?
local function on_player_or_pet_pre_damage(_, attacker)
  return should_block_player_damage(attacker)
end

---@param victim Mount
---@param attacker Movable
---@return boolean?
local function on_mount_pre_damage(victim, attacker)
  -- Only protect tamed mounts
  if not victim.tamed then
    return nil
  end
  return should_block_player_damage(attacker)
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
    entity:set_pre_damage(on_player_or_pet_pre_damage)
  elseif options.spare_pets and is_pet(entity) then
    entity:set_pre_damage(on_player_or_pet_pre_damage)
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

set_callback(save_options, ON.SAVE)
set_callback(load_options, ON.LOAD)

set_post_entity_spawn(on_spawn, SPAWN_TYPE.ANY, MASK.ANY)
