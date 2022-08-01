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
local shaderDisfactor = 0
local customSfx = {
    STOP_TIME_DIO = Isaac.GetSoundIdByName("StopDio"),
    RESUME_TIME_DIO = Isaac.GetSoundIdByName("ResumeDio"),
    STOP_TIME_JOTARO = Isaac.GetSoundIdByName("StopJotaro"),
    RESUME_TIME_JOTARO = Isaac.GetSoundIdByName("ResumeJotaro"),
    STOP_TIME_DIEGO = Isaac.GetSoundIdByName("StopDiego"),
    RESUME_TIME_DIEGO = Isaac.GetSoundIdByName("ResumeDiego"),
    TICK_5 = Isaac.GetSoundIdByName("Tick5"),
    TICK_9 = Isaac.GetSoundIdByName("Tick9")
}
local voiceSfxDio = {
    Isaac.GetSoundIdByName("DioIntro1"),
    Isaac.GetSoundIdByName("DioIntro2"),
    Isaac.GetSoundIdByName("DioIntro3"),
    Isaac.GetSoundIdByName("DioIntro4")
}
local voiceSfxJotaro = {
    Isaac.GetSoundIdByName("JotaroIntro1"),
    Isaac.GetSoundIdByName("JotaroIntro2")
}
local voiceSfxDiego = {
    Isaac.GetSoundIdByName("DiegoIntro1"),
    Isaac.GetSoundIdByName("DiegoIntro2"),
    Isaac.GetSoundIdByName("DiegoIntro3"),
    Isaac.GetSoundIdByName("DiegoIntro4")
}
-- default values
local effectVariant = "Dio"
local voiceOver = false
local useOldShader = false
local invertColors = true

local outroTimeMarker = effectVariant == "Diego" and 60.0 or (effectVariant == "Dio" and 40.0 or 15.0)
local longWindup = false
local maxTime = 260
local canShoot = {true, true, true, true}
local playerID = 0
---------------------------------------------------------------------------
------------------------------HANDLERS-------------------------------------

local startingSfxHandler = {
    ["Dio"] = function()
        if voiceOver then
            local idx = math.random(4)
            longWindup = idx == 2 or idx == 3
            sfx:Play(voiceSfxDio[idx], 1, 0, false, 1, 0)
        end
        if not longWindup then
            sfx:Play(customSfx.STOP_TIME_DIO, 2, 0, false, 1, 0)
        end
    end,
    ["Jotaro"] = function()
        if voiceOver then
            sfx:Play(voiceSfxJotaro[math.random(2)], 1, 0, false, 1, 0)
        end
        sfx:Play(customSfx.STOP_TIME_JOTARO, 1, 0, false, 1, 0)
    end,
    ["Diego"] = function()
        if voiceOver then
            sfx:Play(voiceSfxDiego[math.random(4)], 2, 0, false, 1, 0)
        end
        sfx:Play(customSfx.STOP_TIME_DIEGO, 1.25, 0, false, 1, 0)
    end
}

local finishingSfxHandler = {
    ["Dio"] = function()
        sfx:Play(customSfx.RESUME_TIME_DIO, 2, 0, false, 1, 0)
    end,
    ["Jotaro"] = function()
        sfx:Play(customSfx.RESUME_TIME_JOTARO, 3, 0, false, 1, 0)
    end,
    ["Diego"] = function()
        sfx:Play(customSfx.RESUME_TIME_DIEGO, 1, 0, false, 0.925, 0)
    end
}

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
---------------------------HELPER METHODS----------------------------------
function TimeStop:GetID(ent)
    for i = 0, 3 do
        if Isaac.GetPlayer(i).Index == ent.Index then return i end
    end
end

---------------------------------------------------------------------------
-----------------------------MOD SUPPORT-----------------------------------
local desc = "# Halts the flow of time for what feels like 5 seconds" ..
        "# The player can interact with other objects, move, and shoot freely during stopped time, " ..
        "while also being immune to most damage" ..
        "# All other enemies, familiars, and projectiles stay frozen in place" ..
        "# Explosions are halted, and bombs explode after time resumes"
-- Unknown prevalence of en_us_detailed
local detailed_desc = desc

if EID then
    EID:addCollectible(item, desc ..
            "#{{Collectible356}} Increases the duration of stopped time to 9 seconds", _, "en_us")
    EID:addCollectible(item, detailed_desc ..
            "#{{Collectible356}} Increases the duration of stopped time to 9 seconds", _, "en_us_detailed")
end

if Encyclopedia then
    Encyclopedia.AddItem({
        ID = item,
        WikiDesc = {
            Encyclopedia.EIDtoWiki(detailed_desc)[1],
            {
                { str = "Interactions", fsize = 2, clr = 3, halign = 0 },
                { str = "Car Battery: Increases the duration of stopped time to 9 seconds" }
            },
            {
                { str = "Trivia", fsize = 2, clr = 3, halign = 0 },
                { str = "Definitely not a jojo reference." }
            }
        },
        Pools = {
            Encyclopedia.ItemPools.POOL_TREASURE
        },
        ModName = "Updated Chronoscope (ZA WARUDO)"
    })
end

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
    ModConfigMenu.AddSetting(
            "Updated Chronoscope",
            "General",
            {
                Type = ModConfigMenu.OptionType.NUMBER,
                CurrentSetting = function()
                        return useOldShader and 1 or 2
                end,
                Minimum = 1,
                Maximum = 2,
                Display = function()
                    local textval = useOldShader and "Legacy" or "Realistic"
                    return "Shader variant: " .. textval
                end,
                OnChange = function(val)
                    useOldShader = (val == 1)
                    SaveConfig()
                end,
                Info = function()
                    return { "Changes time stop shader/visual effect. Realistic refers to the JoJo-like visual effect" }
                end
            }
    )
end

function SaveConfig()
    TimeStop:SaveData(json.encode({ voiceOver = voiceOver, effectVariant = effectVariant, useOldShader = useOldShader,
                                    invertColors = invertColors }))
end
---------------------------------------------------------------------------
-------------------------CALLBACK FUNCTIONS--------------------------------
function TimeStop:onUse(_, _, player, flags)
    if flags & UseFlag.USE_CARBATTERY ~= 0 then
        return false
    end
    playerID = TimeStop:GetID(player)
    room = Game():GetLevel():GetCurrentRoomIndex()
    startingSfxHandler[effectVariant]()
    if player:HasCollectible(Isaac.GetItemIdByName("Car Battery")) then
        if longWindup then freezetime = 410
        else freezetime = 380 end
    else
        if longWindup then freezetime = 290
        else freezetime = 260 end
    end
    savedtime = game.TimeCounter
    music:Pause()

    player:AnimateCollectible(item, "LiftItem", "PlayerPickup")
    player:AddControlsCooldown(longWindup and 185 or 125)
    return false
end

function TimeStop:onUpdate()
    if freezetime == 0 then return end

    local player = Isaac.GetPlayer(playerID)
    local entities = Isaac.GetRoomEntities()
    if room ~= Game():GetLevel():GetCurrentRoomIndex() then
        --reset when leaving room
        freezetime = 1
        for _, v in pairs(customSfx) do
            sfx:Stop(v)
        end
    end

    -- in case of skipped frames
    if freezetime == 320 and player:HasCollectible(Isaac.GetItemIdByName("Car Battery")) then
        player:AnimateCollectible(item, "HideItem", "PlayerPickup")
        sfx:Play(customSfx.TICK_9, 5, 0, false, 1, 0)
    elseif freezetime == 200 and not player:HasCollectible(Isaac.GetItemIdByName("Car Battery")) then
        player:AnimateCollectible(item, "HideItem", "PlayerPickup")
        sfx:Play(customSfx.TICK_5, 5, 0, false, 1, 0)
    elseif freezetime == outroTimeMarker then
        finishingSfxHandler[effectVariant]()
    elseif freezetime == 0 then
        music:Resume()
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
                    if familiarVec[v.Index] then
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
    elseif freezetime > 1 --[[and (not longWindup or (maxTime - freezetime >= 0))--]] then
        -- while on effect
        game.TimeCounter = savedtime
        for _, v in pairs(entities) do
            if v.Type == EntityType.ENTITY_FAMILIAR and canShoot[playerID + 1] then
                local fam = v:ToFamiliar()
                fam.FireCooldown = freezetime + 35
                if not v:HasEntityFlags(EntityFlag.FLAG_FREEZE) then
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
                    local bomb = v:ToBomb()
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
    end
    freezetime = math.max(0, freezetime - 1)
end

function TimeStop:onShader(name)
    if name == "ZaWarudoClassic" then

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

        return {
            Enabled = useOldShader and 1 or 0,
            DistortionScale = dist,
            DistortionOn = on
        }

    elseif name == "ZaWarudo" then
        local pos = Isaac.WorldToScreen(Isaac.GetPlayer(playerID).Position)
        local diff = maxTime - freezetime
        local t = 0
        local gscale = freezetime == 0 and 0 or 0.7 -
                0.45 * math.max(outroTimeMarker - freezetime, 0) / outroTimeMarker

        if freezetime == 0 or diff <= 5 then
            t = -10
            -- first wave
        elseif diff < 40 then t = (diff - 4) / 12.0
            -- second (incoming) wave
        elseif diff < 60 then t = (61 - diff) / 8.0
        else t = -10 end

        if diff == 8 and not useOldShader then
            Game():ShakeScreen(8)
            for _,v in pairs(Isaac.GetRoomEntities()) do
                v:SetColor(Color(0.4, 0.4, 1.0, 1.0, 0.0, 0.0, 0.0), 50, 0, false, false)
            end
        elseif diff % 15 == 0 and diff < 60 then
            shaderDisfactor =  math.random(4)
            shaderDisfactor = (shaderDisfactor <= 2) and (-1 * shaderDisfactor) or math.floor(shaderDisfactor / 2)
        end

        return {
            Enabled = (not useOldShader and freezetime ~= 0 and diff > 0) and ((diff < 40) and 1 or 2) or 0,
            Time = t,
            PlayerPos = { pos.X / Isaac.GetScreenWidth(), pos.Y / Isaac.GetScreenHeight() },
            Thickness = t * 5.5,
            GreyScale = gscale,
            Distort = t * shaderDisfactor / 16,
            Inverted = invertColors and 1 or 0
        }

    elseif name == "ZaWarudoBlur" then
        local diff = maxTime - freezetime
        local pos = Isaac.WorldToScreen(Isaac.GetPlayer(playerID).Position)
        local s = 0
        if diff < 10 then s = diff * 3
        elseif diff < 40 then s = 30
        else s = math.max(0, 60 - diff) end

        return {
            Enabled = (not useOldShader and freezetime ~= 0 and diff < 60 and diff > 10) and 1 or 0,
            PlayerPos = { pos.X / Isaac.GetScreenWidth(), pos.Y / Isaac.GetScreenHeight() },
            Strength = s
        }

    elseif name == "ZaWarudoZoom" then
        local diff = maxTime - freezetime
        local pos = Isaac.WorldToScreen(Isaac.GetPlayer(playerID).Position)
        local z = 1
        if diff < 10 and diff > 5 then z = 1 - (diff - 5) * 0.02
        elseif diff < 60 then z = 0.9 end

        return {
            Enabled = (not useOldShader and freezetime ~= 0 and diff < 60) and 1 or 0,
            PlayerPos = { pos.X / Isaac.GetScreenWidth(), pos.Y / Isaac.GetScreenHeight() },
            Zoom = z
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
        if not Isaac.GetPlayer(playerID):HasCollectible(CollectibleType.COLLECTIBLE_BRIMSTONE) then
            data.LaserHit = data.LaserHit and data.LaserHit + 1 or 1
        end
        return false
    end
    if freezetime > 1 and target.Type ~= EntityType.ENTITY_PLAYER and flags & DamageFlag.DAMAGE_EXPLOSION ~= 0 then
        local data = target:GetData()
        data.Explodes = data.Explodes and data.Explodes + 1 or 1
        if Isaac.GetPlayer(playerID):HasCollectible(CollectibleType.COLLECTIBLE_EPIC_FETUS) then
            data.Explodes = data.Explodes - 1 + Isaac.GetPlayer(playerID).Damage * 0.2
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
        useOldShader = config.useOldShader
        invertColors = config.invertColors
        outroTimeMarker = effectVariant == "Diego" and 60.0 or (effectVariant == "Dio" and 40.0 or 15.0)
    end
end

function TimeStop:onGameExit()
    for _, v in pairs(customSfx) do
        sfx:Stop(v)
    end
end

function TimeStop:onCacheEval(ent)
    maxTime = ent:HasCollectible(Isaac.GetItemIdByName("Car Battery")) and 380 or 260
end

TimeStop:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, TimeStop.onCacheEval)
TimeStop:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, TimeStop.onGameExit)
TimeStop:AddCallback(ModCallbacks.MC_POST_TEAR_UPDATE, TimeStop.onTearUpdate)
TimeStop:AddCallback(ModCallbacks.MC_POST_TEAR_UPDATE, TimeStop.onTearUpdate_Nail, TearVariant.NAIL)
TimeStop:AddCallback(ModCallbacks.MC_POST_PROJECTILE_UPDATE, TimeStop.onProjectileUpdate)
TimeStop:AddCallback(ModCallbacks.MC_GET_SHADER_PARAMS, TimeStop.onShader)
TimeStop:AddCallback(ModCallbacks.MC_USE_ITEM, TimeStop.onUse, item)
TimeStop:AddCallback(ModCallbacks.MC_POST_UPDATE, TimeStop.onUpdate)
TimeStop:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, TimeStop.onDamage)
TimeStop:AddCallback(ModCallbacks.MC_POST_PLAYER_INIT, TimeStop.onGameStarted)