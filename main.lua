local TimeStop = RegisterMod("ZaWarudo", 1)
local game = Game()
local sfx = SFXManager()
local music = MusicManager()
local json = require("json")
local savedtime = 0
local freezetime = 0
local room = -1
local item = Isaac.GetItemIdByName("Chronoscope")
local BrimKnifeRandomV = Vector(0, 0)
local familiarVec = { }
local customSfx = {
    STOP_TIME = Isaac.GetSoundIdByName("Stop"),
    RESUME_TIME = Isaac.GetSoundIdByName("Resume"),
    TICK_5 = Isaac.GetSoundIdByName("Tick5"),
    TICK_9 = Isaac.GetSoundIdByName("Tick9")
}
local effectVariant = "Dio"
local voiceOver = false

local outroTimeMarker = effectVariant == "Diego" and 60.0 or (effectVariant == "Dio" and 40.0 or 15.0)
local longWindup = false
local familiarHandler = {
    ["orbital"] = function(fam)
        local data = fam:GetData()
        fam:AddToOrbit(data.StoredLayer)
        fam.OrbitDistance = data.StoredDist
        fam.OrbitSpeed = data.StoredOrbSpeed
        data.StoredOrbSpeed = nil
        data.StoredDist = nil
        data.StoredLayer = nil
    end,
    ["delayed"] = function(fam)
        fam:AddToDelayed()
    end,
    ["follower"] = function(fam)
        fam:AddToFollowers()
        fam:FollowParent()
    end
}

---------------------------------------------------------------------------
-----------------------------MOD SUPPORT-----------------------------------

if ModConfigMenu then

    local effectVariants = { "Dio", "Jotaro", "Diego" }
    ModConfigMenu.AddSetting(
            "Updated Chronoscope",
            "General",
            {
                Type = ModConfigMenu.OptionType.NUMBER,
                CurrentSetting = function()
                    local idx = 0
                    for i, v in ipairs(effectVariants) do
                        if v == effectVariant then
                            idx = i
                            break
                        end
                    end
                    return idx
                end,
                Minimum = 1,
                Maximum = 3,
                Display = function()
                    return "Sound effect variant: " .. effectVariant
                end,
                OnChange = function(val)
                    effectVariant = effectVariants[val]
                    outroTimeMarker = effectVariant == "Diego" and 60.0 or (effectVariant == "Dio" and 40.0 or 15.0)
                    longWindup = false
                    SaveConfig()
                end,
                Info = function()
                    return { "Changes time stop sound effect. Based on all JoJo characters with that ability." }
                end
            }
    )
    ModConfigMenu.AddSetting(
            "Updated Chronoscope",
            "General",
            {
                Type = ModConfigMenu.OptionType.BOOLEAN,
                CurrentSetting = function()
                    return voiceOver
                end,
                Display = function()
                    local booleanval = voiceOver and "True" or "False"
                    return "Voice over enabled: " .. booleanval
                end,
                OnChange = function(val)
                    voiceOver = val
                    longWindup = false
                    SaveConfig()
                end,
                Info = function()
                    return { "Enables character voice overs." }
                end
            }
    )
end

function SaveConfig()
    if ModConfigMenu then
        TimeStop:SaveData(json.encode({ voiceOver = voiceOver, effectVariant = effectVariant }))
    end
end

---------------------------------------------------------------------------
-------------------------CALLBACK FUNCTIONS--------------------------------

    local player = Isaac.GetPlayer(0)
    room = Game():GetLevel():GetCurrentRoomIndex()
    if player:HasCollectible(Isaac.GetItemIdByName("Car Battery")) then
        if longWindup then
            freezetime = 410
            player:AddControlsCooldown(180)
        else
            freezetime = 380
            player:AddControlsCooldown(120)
        end
    else
        if longWindup then
            freezetime = 290
            player:AddControlsCooldown(180)
        else
            freezetime = 260
            player:AddControlsCooldown(120)
        end
    end
    savedtime = game.TimeCounter
    music:Pause()
    return not longWindup
end

function TimeStop:onUpdate()
    local player = Isaac.GetPlayer(0)
    local entities = Isaac.GetRoomEntities()
    if room ~= Game():GetLevel():GetCurrentRoomIndex() then
        --reset when leaving room
        freezetime = 0
        for _, v in pairs(customSfx) do
            sfx:Stop(v)
        end
    end
    if freezetime == 1 then
        --restore tear attributes
        for _, v in pairs(entities) do
            if v:HasEntityFlags(EntityFlag.FLAG_FREEZE) then
                v:ClearEntityFlags(EntityFlag.FLAG_FREEZE)
                v:ClearEntityFlags(EntityFlag.FLAG_NO_SPRITE_UPDATE)
                v:ClearEntityFlags(EntityFlag.FLAG_NO_KNOCKBACK)
                if v:GetData().Explodes then
                    v:TakeDamage(100.0 * v:GetData().Explodes, DamageFlag.DAMAGE_TNT, EntityRef(player), 0)
                    v:GetData().Explodes = nil
                end
                if v:GetData().LaserHit then
                    v:TakeDamage(player.Damage * v:GetData().LaserHit, DamageFlag.DAMAGE_LASER, EntityRef(player), 0)
                    v:GetData().LaserHit = nil
                end
                if v.Type == EntityType.ENTITY_FAMILIAR then
                    v.Parent = player
                    if familiarHandler[familiarVec[v.Index][2]] then
                        familiarHandler[familiarVec[v.Index][2]](v:ToFamiliar())
                    end
                end
                if v.Type == EntityType.ENTITY_TEAR then
                    local data = v:GetData()
                    if data.Frozen then
                        data.Frozen = nil
                        local tear = v:ToTear()
                        v.Velocity = data.StoredVel
                        tear.FallingSpeed = data.StoredFall
                        tear.FallingAcceleration = data.StoredAccel
                        if player:HasCollectible(CollectibleType.COLLECTIBLE_MY_REFLECTION) then
                            tear:AddTearFlags(TearFlags.TEAR_BOOMERANG)
                        end
                        if player:HasCollectible(CollectibleType.COLLECTIBLE_TINY_PLANET) then
                            tear:AddTearFlags(TearFlags.TEAR_ORBIT)
                        end
                    end
                elseif v.Type == EntityType.ENTITY_LASER then
                    local data = v:GetData()
                    data.Frozen = nil
                elseif v.Type == EntityType.ENTITY_KNIFE then
                    local data = v:GetData()
                    data.Frozen = nil
                end
            end
        end
        freezetime = 0
    elseif freezetime > 1 then
        -- while on effect
        game.TimeCounter = savedtime
        for _, v in pairs(entities) do
            if v.Type == EntityType.ENTITY_FAMILIAR then
                local fam = v:ToFamiliar()
                fam.FireCooldown = freezetime + 35
                if not v:HasEntityFlags(EntityFlag.FLAG_FREEZE) then
                    if longWindup and maxTime - freezetime < 0 then
                        return
                    end
                    v:AddEntityFlags(EntityFlag.FLAG_FREEZE)
                    local familiartype = fam.OrbitDistance:Length() ~= 0.0 and "orbital" or "follower"
                    local famdata = fam:GetData()
                    if familiartype == "orbital" then
                        famdata.StoredDist = fam.OrbitDistance
                        famdata.StoredLayer = fam.OrbitLayer
                        famdata.StoredOrbSpeed = fam.OrbitSpeed
                        fam:RemoveFromOrbit()
                    else
                        fam:RemoveFromFollowers()
                    end
                    fam:RemoveFromDelayed()
                    familiarVec[v.Index] = { v.Position, familiartype }
                else
                    v.Position = familiarVec[v.Index][1]
                    v.Velocity = Vector(0, 0)
                    v.Target = nil
                    v.Parent = nil
                end
            elseif v.Type ~= EntityType.ENTITY_PLAYER then
                if v.Type ~= EntityType.ENTITY_PROJECTILE then
                    if not v:HasEntityFlags(EntityFlag.FLAG_FREEZE) then
                        v:AddEntityFlags(EntityFlag.FLAG_FREEZE)
                        v:AddEntityFlags(EntityFlag.FLAG_NO_KNOCKBACK)
                        if v:IsBoss() then
                            v:AddEntityFlags(EntityFlag.FLAG_NO_SPRITE_UPDATE)
                        end
                    end
                end
                if v.Type == EntityType.ENTITY_TEAR then
                    -- handling regular tears
                    local data = v:GetData()
                    if not data.Frozen then
                        if v.Velocity.X ~= 0 or v.Velocity.Y ~= 0
                                or not player:HasCollectible(CollectibleType.COLLECTIBLE_ANTI_GRAVITY) then
                            data.Frozen = true
                            data.StoredVel = v.Velocity
                            local tear = v:ToTear()
                            if player:HasCollectible(CollectibleType.COLLECTIBLE_MY_REFLECTION) then
                                tear:ClearTearFlags(TearFlags.TEAR_BOOMERANG)
                            end
                            if player:HasCollectible(CollectibleType.COLLECTIBLE_TINY_PLANET) then
                                tear:ClearTearFlags(TearFlags.TEAR_ORBIT)
                            end
                            data.StoredFall = tear.FallingSpeed
                            data.StoredAccel = tear.FallingAcceleration
                        else
                            local tear = v:ToTear()
                            tear.FallingSpeed = 0
                        end
                    else
                        local tear = v:ToTear()
                        v.Velocity = Vector(0, 0)
                        if tear:GetData().Knife then
                            tear.SpriteRotation = data.StoredVel:GetAngleDegrees() + 90
                        end
                        tear.FallingAcceleration = -0.1
                        tear.FallingSpeed = 0
                    end
                elseif v.Type == EntityType.ENTITY_BOMBDROP then
                    -- handling bombs
                    bomb = v:ToBomb()
                    bomb:SetExplosionCountdown(2)
                    bomb.Velocity = Vector(0, 0)
                elseif v.Type == EntityType.ENTITY_LASER then
                    -- handling lasers
                    local laser = v:ToLaser()
                    local data = v:GetData()
                    if v.Variant == 1 then
                        if not data.Frozen and not laser:IsCircleLaser() then
                            local newLaser = player:FireBrimstone(Vector.FromAngle(laser.StartAngleDegrees))
                            newLaser.Position = laser.Position
                            newLaser.DisableFollowParent = true
                            local newData = newLaser:GetData()
                            newData.Frozen = true
                            laser.CollisionDamage = -100
                            data.Frozen = true
                            laser.DisableFollowParent = true
                            laser.Visible = false
                        end
                        laser:SetTimeout(19)
                    else
                        laser:SetTimeout(6)
                    end
                elseif v.Type == EntityType.ENTITY_KNIFE then
                    -- handling knives
                    local knife = v:ToKnife()
                    if knife:IsFlying() then
                        local number = 1
                        local offset = 0
                        local offset2 = 0
                        if player:HasCollectible(CollectibleType.COLLECTIBLE_BRIMSTONE) then
                            number = math.random(3 + math.floor(knife.Charge * 3),
                                    4 + math.floor(4 + knife.Charge * 4))
                            offset = math.random(-150, 150) / 10
                            offset2 = math.random(-300, 300) / 1000
                        end
                        for _ = 1, number do
                            local newKnife = player:FireTear(knife.Position, Vector(0, 0), false, true, false)
                            local newData = newKnife:GetData()
                            newData.Knife = true
                            newKnife.TearFlags = player.TearFlags
                            newKnife.Scale = 1
                            newKnife:ResetSpriteScale()
                            newKnife.FallingAcceleration = -0.1
                            newKnife.FallingSpeed = 0
                            newKnife.Height = -10
                            BrimKnifeRandomV.X = 0
                            BrimKnifeRandomV.Y = 1 + offset2
                            newKnife.Velocity = BrimKnifeRandomV:Rotated(knife.Rotation - 90 + offset) * 15
                                    * player.ShotSpeed * math.random(75, 125) / 100.0
                            newKnife.CollisionDamage = 18 * knife.Charge * (player.Damage)
                            newKnife.GridCollisionClass = GridCollisionClass.COLLISION_WALL
                            newKnife.EntityCollisionClass = EntityCollisionClass.ENTCOLL_ALL

                            local sprite = newKnife:GetSprite()
                            sprite:ReplaceSpritesheet(0, "gfx/tearKnife.png")
                            sprite:LoadGraphics()
                            knife:Reset()
                            offset = math.random(-150, 150) / 10
                            offset2 = math.random(-300, 300) / 1000
                        end
                    end
                end
            end
        end
        freezetime = math.max(0, freezetime - 1)
    end
end

function TimeStop:onShader(name)
    if name == "ZaWarudo" then
        local player = Isaac.GetPlayer(0)
        maxTime = player:HasCollectible(Isaac.GetItemIdByName("Car Battery")) and 380 or 260

        --[[ -- copy fade-in effect for fade-out
        local dist = 1 / (maxTime - 12 - freezetime) + 1 / (freezetime - 2)
        local on = 0
        if dist < 0 then
            dist = math.abs(dist) ^ 2
        elseif freezetime == 2 or maxTime - 12 - freezetime == 0 then
            dist = 1
        else
            on = 0.5
        end
        --]]

        local dist = 10 / (maxTime - 12 - freezetime) -- transition factor
        local on = 0 -- dullness factor
        if dist < 0 or freezetime == 0 then
            dist = math.abs(dist) ^ 2
        else
            on = 0.5 - 0.5 * math.max(outroTimeMarker - freezetime, 0) / outroTimeMarker
        end
        -- long windup
        if longWindup and maxTime - freezetime < 0 then
            dist = 0
        end
        -- in case of skipped frames
        if maxTime - freezetime < 2 and maxTime - freezetime > 0 then
            player:AnimateCollectible(item, "LiftItem", "PlayerPickup")
        elseif freezetime == 320 then
            player:AnimateCollectible(item, "HideItem", "PlayerPickup")
            sfx:Play(customSfx.TICK_9, 5, 0, false, 1)
        elseif freezetime == 200 and not player:HasCollectible(Isaac.GetItemIdByName("Car Battery")) then
            player:AnimateCollectible(item, "HideItem", "PlayerPickup")
            sfx:Play(customSfx.TICK_5, 5, 0, false, 1)
        elseif freezetime == 40 then
            sfx:Play(customSfx.RESUME_TIME, 2, 0, false, 1)
        elseif freezetime == 0 then
            music:Resume()
        end

        return {
            DistortionScale = dist,
            DistortionOn = on
        }
    end
end

function TimeStop:onProjectileUpdate(tear)
    local data = tear:GetData()
    if freezetime == 1 then
        data.Frozen = false
        tear.Velocity = data.StoredVelocity
        tear.FallingSpeed = data.StoredFallingSpeed
        tear.FallingAccel = data.StoredAccel
    elseif freezetime > 1 then
        if not data.Frozen then
            data.Frozen = true
            data.StoredVelocity = tear.Velocity
            data.StoredFallingSpeed = tear.FallingSpeed
            data.StoredAccel = tear.FallingAccel
        else
            tear.Velocity = Vector(0, 0)
            tear.FallingAccel = -0.1
            tear.FallingSpeed = 0
        end
    end
end

function TimeStop:onDamage(target, _, flags, source, _)
    if freezetime > 0 and target.Type == EntityType.ENTITY_PLAYER and flags & DamageFlag.DAMAGE_POISON_BURN == 0
            and flags & DamageFlag.DAMAGE_FIRE == 0 and flags & DamageFlag.DAMAGE_CURSED_DOOR == 0 then
        return false
    end
    if freezetime > 1 and source.Type == EntityType.ENTITY_PLAYER and flags & DamageFlag.DAMAGE_LASER ~= 0 then
        local data = target:GetData()
        if not Isaac.GetPlayer(0):HasCollectible(CollectibleType.COLLECTIBLE_BRIMSTONE) then
            data.LaserHit = data.LaserHit and data.LaserHit + 1 or 1
        end
        return false
    end
    if freezetime > 1 and target.Type ~= EntityType.ENTITY_PLAYER and flags & DamageFlag.DAMAGE_EXPLOSION ~= 0 then
        local data = target:GetData()
        data.Explodes = data.Explodes and data.Explodes + 1 or 1
        if Isaac.GetPlayer(0):HasCollectible(CollectibleType.COLLECTIBLE_EPIC_FETUS) then
            data.Explodes = data.Explodes - 1 + Isaac.GetPlayer(0).Damage * 0.2
        end
        return false
    end
end

function TimeStop:onTearUpdate(tear)
    if tear:GetData().Knife and freezetime == 0 then
        tear.SpriteRotation = tear.Velocity:GetAngleDegrees() + 90
    end
end

function TimeStop:onTearUpdate_Nail(tear)
    if tear:GetData().StoredVel then
        tear.SpriteRotation = tear:GetData().StoredVel:GetAngleDegrees()
    end
end

function TimeStop:onGameStarted()
    freezetime = 0
    if ModConfigMenu and TimeStop:HasData() then
        local config = json.decode(TimeStop:LoadData())
        voiceOver = config.voiceOver
        effectVariant = config.effectVariant
        outroTimeMarker = effectVariant == "Diego" and 60.0 or (effectVariant == "Dio" and 40.0 or 15.0)
    end
end

function TimeStop:onGameExit()
    for _, v in pairs(customSfx) do
        sfx:Stop(v)
    end
end

TimeStop:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, TimeStop.onGameExit)
TimeStop:AddCallback(ModCallbacks.MC_POST_TEAR_UPDATE, TimeStop.onTearUpdate)
TimeStop:AddCallback(ModCallbacks.MC_POST_TEAR_UPDATE, TimeStop.onTearUpdate_Nail, TearVariant.NAIL)
TimeStop:AddCallback(ModCallbacks.MC_POST_PROJECTILE_UPDATE, TimeStop.onProjectileUpdate)
TimeStop:AddCallback(ModCallbacks.MC_GET_SHADER_PARAMS, TimeStop.onShader)
TimeStop:AddCallback(ModCallbacks.MC_USE_ITEM, TimeStop.onUse, item)
TimeStop:AddCallback(ModCallbacks.MC_POST_UPDATE, TimeStop.onUpdate)
TimeStop:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, TimeStop.onDamage)
TimeStop:AddCallback(ModCallbacks.MC_POST_PLAYER_INIT, TimeStop.onGameStarted)