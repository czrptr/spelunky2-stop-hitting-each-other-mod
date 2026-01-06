-- STOP HITTING EACH OTHER MOD
meta = {
  name = "Stop hitting each other",
  version = "1.0",
  description = "No friendly or self damage",
  author = "Quasar",
}

-- ==============================================================================

---@param entity Entity
---@return boolean
local function is_player(entity)
  ---@diagnostic disable-next-line undefined-field
  return entity ~= nil and entity.get_short_name ~= nil
end

---@param entity Entity
---@return boolean
local function is_pet(entity)
  ---@diagnostic disable-next-line undefined-field
  return entity ~= nil and entity.petted_counter ~= nil
end

---@param entity Entity
---@return boolean
local function is_mount(entity)
  ---@diagnostic disable-next-line undefined-field
  return entity ~= nil and entity.tamed ~= nil
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
  -- Allow environmental damage (spikes, lava, etc.)
  if not attacker then
    return nil
  end

  -- Block direct player damage
  if is_player(attacker) then
    return false
  end

  -- Block damage from player ridden mounts
  if attacker.type.id == ENT_TYPE.ITEM_TURKEY_NECK then
    local turkey = get_entity(attacker.last_owner_uid) --[[@as Mount]]
    local rider = get_entity(turkey.rider_uid)
    return not is_player(rider)
  end

  if is_mount(attacker) then
    ---@cast attacker Mount
    if attacker.rider_uid ~= -1 then
      local rider = get_entity(attacker.rider_uid)
      return not is_player(rider)
    end
    return nil
  end

  -- Check if projectile/weapon is owned by a player
  local owner = get_entity(attacker.last_owner_uid)
  -- Not player-owned, allow damage
  if not is_player(owner) then
    return nil
  end

  -- Arrows from traps should still hurt
  ---@diagnostic disable-next-line undefined-field
  if attacker.shot_from_trap then
    return nil
  end

  -- Explosions caused by player action should still hurt
  if is_explosion(attacker.type.id) then
    return nil
  end

  -- Block all other player originating damage
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
  -- Allow tamed turkeys to be cooked
  if victim.type.id == ENT_TYPE.MOUNT_TURKEY then
    if attacker.type.id == ENT_TYPE.ITEM_TORCH
        and (attacker --[[@as Torch]]).is_lit then
      return nil
    elseif attacker.type.id == ENT_TYPE.ITEM_WOODEN_ARROW
        and (attacker --[[@as Arrow]]).is_on_fire then
      return nil
    elseif attacker.type.id == ENT_TYPE.ITEM_WHIP and
        (attacker --[[@as Whip]]).flaming then
      return nil
    end
  end
  -- Only protect tamed mounts
  if not victim.tamed then
    return nil
  end
  return should_block_player_damage(attacker)
end

---@param victim Movable
---@param attacker Movable
---@return boolean?
local function on_item_pre_damage(attacker, victim)
  if victim.user_data ~= nil
      and victim.user_data.holder_uid ~= -1
      and is_player(get_entity(victim.user_data.holder_uid)) then
    return attacker.last_owner_uid == -1
  end
  return nil
end

---@param self Player
---@return boolean
local function on_player_pre_drop(self)
  local held_entity = get_entity(self.holding_uid)
  held_entity.user_data.holder_uid = -1
  return false
end

---@param self Player
---@param entity Entity
local function on_player_post_pickup(self, entity)
  -- guard against other mods which use user_data
  if entity.user_data == nil then
    ---@diagnostic disable-next-line: missing-fields
    entity.user_data = {}
  end
  entity.user_data.holder_uid = self.uid
end

---@param self Movable
---@param entity Entity
local function on_item_post_pickup(self, entity)
  ---@diagnostic disable-next-line undefined-field
  if entity.shot_from_trap ~= nil then
    ---@cast entity Arrow
    entity.shot_from_trap = not is_player(self)
  end
end

---@param entity Entity
local function on_spawn(entity)
  ---@diagnostic disable-next-line unknowd_field
  if entity.set_pre_damage == nil then
    return
  end
  ---@cast entity Movable

  if is_player(entity) then
    entity:set_post_pick_up(on_player_post_pickup)
    entity:set_pre_drop(on_player_pre_drop)
    entity:set_pre_damage(on_player_or_pet_pre_damage)
  elseif options.spare_pets and is_pet(entity) then
    entity:set_pre_damage(on_player_or_pet_pre_damage)
  elseif options.spare_mounts and is_mount(entity) then
    entity:set_pre_damage(on_mount_pre_damage)
  elseif test_flag(entity.flags, ENT_FLAG.PICKUPABLE) then
    entity:set_post_pick_up(on_item_post_pickup)
    entity:set_pre_thrown_into(on_item_pre_damage)
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
