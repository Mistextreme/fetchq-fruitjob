-- =========================================================================
-- client/utils.lua
-- Shared utility functions for the client-side of the transport script
-- =========================================================================

Utils = {}

--- Loads a model (Ped, Vehicle or Prop) synchronously.
--- @param model string|number  Model name or hash
--- @return number hash
function Utils.LoadModel(model)
    local hash = type(model) == 'string' and GetHashKey(model) or model

    if not HasModelLoaded(hash) then
        RequestModel(hash)
        while not HasModelLoaded(hash) do
            Wait(10)
        end
    end

    return hash
end

--- Loads an animation dictionary synchronously.
--- @param dict string  Animation dictionary name
function Utils.LoadAnimDict(dict)
    if not HasAnimDictLoaded(dict) then
        RequestAnimDict(dict)
        while not HasAnimDictLoaded(dict) do
            Wait(10)
        end
    end
end

--- Creates a static NPC (depot guard, delivery receiver, etc.)
--- @param model   string          Model name
--- @param coords  vector3|vector4 Spawn coordinates (vector4.w used as heading when present)
--- @param heading number          Fallback heading when coords is a vector3
--- @return number ped
function Utils.CreateNPC(model, coords, heading)
    local hash       = Utils.LoadModel(model)
    local pedHeading = coords.w or heading or 0.0

    local ped = CreatePed(4, hash, coords.x, coords.y, coords.z, pedHeading, false, true)

    SetEntityHeading(ped, pedHeading)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetModelAsNoLongerNeeded(hash)

    return ped
end

--- Creates and configures a map blip.
--- @param coords vector3
--- @param sprite number
--- @param color  number
--- @param scale  number
--- @param label  string
--- @return number blip
function Utils.CreateBlip(coords, sprite, color, scale, label)
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)

    SetBlipSprite(blip, sprite)
    SetBlipColour(blip, color)
    SetBlipScale(blip, scale)
    SetBlipAsShortRange(blip, true)

    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(label)
    EndTextCommandSetBlipName(blip)

    return blip
end

--- Spawns a vehicle at the given vector4 coords.
--- @param model  string
--- @param coords vector4
--- @return number vehicle
function Utils.SpawnVehicle(model, coords)
    local hash    = Utils.LoadModel(model)
    local vehicle = CreateVehicle(hash, coords.x, coords.y, coords.z, coords.w, true, false)

    SetEntityAsMissionEntity(vehicle, true, true)
    SetVehicleHasBeenOwnedByPlayer(vehicle, true)
    SetVehicleNeedsToBeHotwired(vehicle, false)
    SetModelAsNoLongerNeeded(hash)

    return vehicle
end

--- Spawns a prop (fruit crates, etc.)
--- @param model       string
--- @param coords      vector3
--- @param isNetworked boolean  True for group-mode crates that all players must see
--- @return number prop
function Utils.SpawnProp(model, coords, isNetworked)
    local hash = Utils.LoadModel(model)
    local prop = CreateObject(hash, coords.x, coords.y, coords.z, isNetworked, true, false)

    if isNetworked then
        local netId = ObjToNet(prop)
        SetNetworkIdExistsOnAllMachines(netId, true)
        NetworkSetNetworkIdDynamic(netId, true)
        SetNetworkIdCanMigrate(netId, false)
    end

    SetModelAsNoLongerNeeded(hash)

    return prop
end

--- Plays an animation on a ped.
--- NOTE: The animation dictionary is loaded but intentionally NOT released here,
--- because TaskPlayAnim is non-blocking.  The dict must remain loaded for the
--- full duration of the animation.  The game will manage streaming lifecycle.
--- @param ped  number
--- @param dict string
--- @param name string
--- @param flag number  (default 49 — looping + secondary task + allow rotation)
function Utils.PlayAnim(ped, dict, name, flag)
    Utils.LoadAnimDict(dict)
    TaskPlayAnim(ped, dict, name, 8.0, -8.0, -1, flag or 49, 0, false, false, false)
    -- RemoveAnimDict intentionally omitted: freeing a dict while a TaskPlayAnim
    -- is still using it stops the animation immediately on the next frame.
end

--- Safely deletes any entity (vehicle, ped, or object).
--- @param entity number
function Utils.DeleteEntity(entity)
    if entity and DoesEntityExist(entity) then
        if IsEntityAVehicle(entity) then
            DeleteVehicle(entity)
        elseif IsEntityAPed(entity) then
            DeletePed(entity)
        else
            DeleteObject(entity)
        end
    end
end

--- Displays an ox_lib notification.
--- @param msg     string
--- @param msgType string  'success' | 'error' | 'inform'
function Utils.ShowNotification(msg, msgType)
    lib.notify({
        title       = 'Fruit Transport',
        description = msg,
        type        = msgType or 'inform',
        position    = 'top-right',
    })
end

--- Renders a 3-D text label in world space (fallback for areas without target).
--- @param x    number
--- @param y    number
--- @param z    number
--- @param text string
function Utils.DrawText3D(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    if onScreen then
        SetTextScale(0.35, 0.35)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextColour(255, 255, 255, 215)
        SetTextEntry('STRING')
        SetTextCentre(1)
        AddTextComponentString(text)
        DrawText(_x, _y)
        local factor = string.len(text) / 370
        DrawRect(_x, _y + 0.0125, 0.015 + factor, 0.03, 41, 11, 41, 68)
    end
end