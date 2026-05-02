-- =========================================================================
-- client/main.lua
-- Core gameplay logic — Fruit Transport Job
-- Handles: job flow, NPC spawning, crate loading (solo & group),
--          weigh station, deliveries, NUI, ox_target / qb-target / fallback
-- =========================================================================

-- =========================================================================
-- FRAMEWORK DETECTION
-- =========================================================================
local QBCore = nil
local ESX    = nil

if GetResourceState('qb-core') == 'started' then
    QBCore = exports['qb-core']:GetCoreObject()
elseif GetResourceState('es_extended') == 'started' then
    ESX = exports['es_extended']:getSharedObject()
end

-- =========================================================================
-- STATE
-- =========================================================================
local jobActive        = false
local jobMode          = nil     -- 'solo' | 'group'
local jobPhase         = 'idle'  -- 'idle'|'go_farm'|'at_farm'|'loading'|'go_scale'|'at_scale'|'delivering'|'done'
local docType          = nil     -- Config.Documents.green | .red

-- Truck
local currentTruck     = nil
local truckBlip        = nil

-- Crate loading
local cratesLoaded     = 0
local totalCrates      = 0
local farmCrateObjs    = {}   -- table of crate entity handles (group mode)
local isCarryingCrate  = false
local carryCrateObj    = nil

-- Deliveries
local deliveryPoints   = {}
local deliveriesTotal  = 0
local deliveriesDone   = 0
local deliveryBlips    = {}

-- Static world entities (created once at init, persist for the session)
local depotNpc         = nil
local depotBlip        = nil
local farmBlip         = nil
local scaleBlip        = nil

-- =========================================================================
-- TARGET HELPERS
-- =========================================================================
local function HasOxTarget()
    return GetResourceState('ox_target') == 'started'
end

local function HasQBTarget()
    return GetResourceState('qb-target') == 'started'
end

-- =========================================================================
-- NUI HELPER
-- =========================================================================
local function NUI(data)
    SendNUIMessage(data)
end

-- =========================================================================
-- CLEANUP  — resets all job state and removes spawned entities
-- =========================================================================
local function Cleanup()
    jobActive      = false
    jobMode        = nil
    jobPhase       = 'idle'
    docType        = nil
    cratesLoaded   = 0
    totalCrates    = 0
    deliveriesDone = 0
    deliveriesTotal = 0

    -- Stop player carry animation and drop crate
    local ped = PlayerPedId()
    if isCarryingCrate then
        isCarryingCrate = false
        if carryCrateObj and DoesEntityExist(carryCrateObj) then
            DetachEntity(carryCrateObj, true, true)
            Utils.DeleteEntity(carryCrateObj)
        end
        carryCrateObj = nil
        ClearPedTasks(ped)
    end

    -- Remove any remaining farm crates
    for _, obj in pairs(farmCrateObjs) do
        if obj then Utils.DeleteEntity(obj) end
    end
    farmCrateObjs = {}

    -- Delete truck
    if currentTruck and DoesEntityExist(currentTruck) then
        Utils.DeleteEntity(currentTruck)
    end
    currentTruck = nil

    -- Remove truck blip
    if truckBlip and DoesBlipExist(truckBlip) then
        RemoveBlip(truckBlip)
        truckBlip = nil
    end

    -- Remove delivery blips
    for _, blip in pairs(deliveryBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    deliveryBlips = {}
    deliveryPoints = {}

    -- Clear GPS routes on persistent blips
    if farmBlip  and DoesBlipExist(farmBlip)  then SetBlipRoute(farmBlip,  false) end
    if scaleBlip and DoesBlipExist(scaleBlip) then SetBlipRoute(scaleBlip, false) end

    -- Hide NUI elements
    NUI({ action = 'hideObjectives' })
    NUI({ action = 'hideDocument' })
end

-- =========================================================================
-- DELIVERY POINT SELECTION  — random subset from Config.DeliveryPoints
-- =========================================================================
local function SelectDeliveryPoints()
    local all    = Config.DeliveryPoints.locations
    local count  = math.random(Config.DeliveryPoints.count, Config.DeliveryPoints.countMax)
    local result = {}
    local used   = {}

    while #result < count do
        local idx = math.random(1, #all)
        if not used[idx] then
            used[idx] = true
            result[#result + 1] = all[idx]
        end
    end

    return result
end

-- =========================================================================
-- JOB FINISH  — triggers server payment
-- =========================================================================
local function FinishJob()
    if not docType then return end

    jobPhase = 'done'
    TriggerServerEvent('fetchq-fruitjob:server:FinishJob', docType)
    NUI({ action = 'updateObjective', key = 'deliver', completed = true,
          counter = deliveriesDone, total = deliveriesTotal })
    Wait(1200)
    Cleanup()
end

-- =========================================================================
-- DELIVERY FLOW
-- =========================================================================
local function StartDeliveryPhase()
    if not jobActive then return end

    jobPhase        = 'delivering'
    deliveriesTotal = #deliveryPoints
    deliveriesDone  = 0

    Utils.ShowNotification(
        string.format(Config.Notifications.deliveryStart, deliveriesTotal),
        'inform'
    )

    -- Spawn delivery blips
    for i, point in ipairs(deliveryPoints) do
        deliveryBlips[i] = Utils.CreateBlip(
            point.coords,
            Config.DeliveryPoints.blip.sprite,
            Config.DeliveryPoints.blip.color,
            Config.DeliveryPoints.blip.scale,
            point.label
        )
    end

    NUI({ action = 'updateObjective', key = 'deliver', completed = false,
          counter = 0, total = deliveriesTotal })

    -- Route to first delivery
    if deliveryBlips[1] and DoesBlipExist(deliveryBlips[1]) then
        SetBlipRoute(deliveryBlips[1], true)
    end

    -- Delivery proximity loop
    CreateThread(function()
        local idx = 1
        while jobActive and jobPhase == 'delivering' and idx <= #deliveryPoints do
            local ped       = PlayerPedId()
            local pedCoords = GetEntityCoords(ped)
            local point     = deliveryPoints[idx]
            local dist      = #(pedCoords - point.coords)

            if dist < Config.DeliveryPoints.interactDistance then
                Utils.DrawText3D(point.coords.x, point.coords.y, point.coords.z + 1.2,
                    Config.Notifications.pressEDeliver)

                if IsControlJustReleased(0, 38) then  -- E key
                    Utils.ShowNotification(Config.Notifications.deliveryProgress, 'inform')

                    local completed = lib.progressBar({
                        duration     = Config.DeliveryPoints.deliveryProgressTime,
                        label        = 'Delivering cargo...',
                        useWhileDead = false,
                        canCancel    = false,
                        anim         = {
                            dict = Config.DeliveryNPC.crateCarryAnimDict,
                            clip = Config.DeliveryNPC.crateCarryAnimName,
                            flag = 49,
                        },
                    })

                    if completed then
                        -- Remove this delivery's blip
                        if deliveryBlips[idx] and DoesBlipExist(deliveryBlips[idx]) then
                            SetBlipRoute(deliveryBlips[idx], false)
                            RemoveBlip(deliveryBlips[idx])
                            deliveryBlips[idx] = nil
                        end

                        deliveriesDone = deliveriesDone + 1

                        Utils.ShowNotification(
                            string.format(Config.Notifications.deliveryComplete,
                                deliveriesDone, deliveriesTotal),
                            'success'
                        )

                        NUI({ action = 'updateObjective', key = 'deliver', completed = false,
                              counter = deliveriesDone, total = deliveriesTotal })

                        idx = idx + 1

                        if deliveriesDone >= deliveriesTotal then
                            Utils.ShowNotification(Config.Notifications.allDeliveriesComplete, 'success')
                            Wait(800)
                            FinishJob()
                            return
                        else
                            -- Route to next delivery
                            if deliveryBlips[idx] and DoesBlipExist(deliveryBlips[idx]) then
                                SetBlipRoute(deliveryBlips[idx], true)
                            end
                        end
                    end
                end

                Wait(0)
            elseif dist < Config.NearDistance then
                Wait(Config.JobCheckIntervalNear)
            else
                Wait(Config.JobCheckInterval)
            end
        end
    end)
end

-- =========================================================================
-- WEIGH STATION FLOW
-- =========================================================================
local function SetupScaleInteraction()
    if scaleBlip and DoesBlipExist(scaleBlip) then
        SetBlipRoute(scaleBlip, true)
    end

    CreateThread(function()
        local arrivedNotified = false

        while jobActive and jobPhase == 'go_scale' do
            local ped  = PlayerPedId()
            local dist = #(GetEntityCoords(ped) - Config.Scale.coords)

            if dist < Config.Scale.interactDistance then
                if not arrivedNotified then
                    arrivedNotified = true
                    Utils.ShowNotification(Config.Notifications.arrivedAtScale, 'inform')
                end

                Utils.DrawText3D(
                    Config.Scale.coords.x,
                    Config.Scale.coords.y,
                    Config.Scale.coords.z + 1.2,
                    Config.Notifications.pressEScale
                )

                if IsControlJustReleased(0, 38) then  -- E key
                    jobPhase = 'at_scale'

                    if scaleBlip and DoesBlipExist(scaleBlip) then
                        SetBlipRoute(scaleBlip, false)
                    end

                    -- Document choice via ox_lib context menu
                    lib.registerContext({
                        id      = 'fetchq_document_choice',
                        title   = Config.MenuTexts.riskTitle,
                        options = {
                            {
                                title       = Config.MenuTexts.safeOption,
                                description = Config.MenuTexts.safeDescription,
                                icon        = 'file-circle-check',
                                onSelect    = function()
                                    docType = Config.Documents.green
                                    TriggerServerEvent('fetchq-fruitjob:server:GiveDocument', docType)
                                    Utils.ShowNotification(Config.Notifications.documentReceived, 'success')
                                    NUI({ action = 'showCertificate', type = 'green' })
                                    NUI({ action = 'updateObjective', key = 'get_document', completed = true })
                                    Wait(2500)
                                    StartDeliveryPhase()
                                end,
                            },
                            {
                                title       = Config.MenuTexts.riskyOption,
                                description = Config.MenuTexts.riskyDescription,
                                icon        = 'file-circle-xmark',
                                onSelect    = function()
                                    docType = Config.Documents.red
                                    TriggerServerEvent('fetchq-fruitjob:server:GiveDocument', docType)
                                    Utils.ShowNotification(Config.Notifications.documentReceived, 'success')
                                    NUI({ action = 'showCertificate', type = 'red' })
                                    NUI({ action = 'updateObjective', key = 'get_document', completed = true })
                                    Wait(2500)
                                    StartDeliveryPhase()
                                end,
                            },
                        },
                    })
                    lib.showContext('fetchq_document_choice')
                    return
                end

                Wait(0)
            elseif dist < Config.NearDistance then
                Wait(Config.JobCheckIntervalNear)
            else
                Wait(Config.JobCheckInterval)
            end
        end
    end)
end

-- =========================================================================
-- GROUP MODE — CRATE LOADING
-- =========================================================================
local function StartGroupLoading()
    if not currentTruck or not DoesEntityExist(currentTruck) then
        Utils.ShowNotification(Config.Notifications.truckNotSpawned, 'error')
        Cleanup()
        return
    end

    jobPhase    = 'loading'
    totalCrates = Config.GroupMode.crateTarget
    cratesLoaded = 0

    Utils.ShowNotification(Config.Notifications.groupCrateInfo, 'inform')
    NUI({ action = 'updateObjective', key = 'load_crates', completed = false,
          counter = 0, total = totalCrates })

    -- Spawn crates at farm positions (offsets relative to Config.Farm.coords)
    for i, offset in ipairs(Config.GroupMode.cratePositions) do
        if i <= totalCrates then
            local spawnPos = vector3(
                Config.Farm.coords.x + offset.x,
                Config.Farm.coords.y + offset.y,
                Config.Farm.coords.z + offset.z
            )
            local obj = Utils.SpawnProp(Config.GroupMode.crateProp, spawnPos, true)
            farmCrateObjs[i] = obj
        end
    end

    -- Proximity pickup + truck-drop loop
    CreateThread(function()
        while jobActive and jobPhase == 'loading' do
            local ped       = PlayerPedId()
            local pedCoords = GetEntityCoords(ped)

            if isCarryingCrate then
                -- Show load prompt when near the truck's rear
                if currentTruck and DoesEntityExist(currentTruck) then
                    local truckCoords = GetEntityCoords(currentTruck)
                    local offset      = Config.Truck.loadMarkerOffset
                    local loadPos     = vector3(
                        truckCoords.x + offset.x,
                        truckCoords.y + offset.y,
                        truckCoords.z + offset.z
                    )

                    if #(pedCoords - loadPos) < Config.Truck.loadMarkerRadius then
                        Utils.DrawText3D(loadPos.x, loadPos.y, loadPos.z + 1.0,
                            Config.Notifications.pressELoad)

                        if IsControlJustReleased(0, 38) then  -- E key
                            -- Detach from player and attach to truck chassis
                            if carryCrateObj and DoesEntityExist(carryCrateObj) then
                                DetachEntity(carryCrateObj, true, true)
                                local truckSlot = Config.SoloMode.crateOnTruckOffsets[cratesLoaded + 1]
                                    or vector3(0.0, -1.5, 0.05)
                                AttachEntityToEntity(
                                    carryCrateObj, currentTruck,
                                    GetEntityBoneIndexByName(currentTruck, 'chassis'),
                                    truckSlot.x, truckSlot.y, truckSlot.z,
                                    0.0, 0.0, 0.0,
                                    false, false, false, false, 2, true
                                )
                            end

                            -- Clear carry state
                            isCarryingCrate = false
                            carryCrateObj   = nil
                            ClearPedTasks(ped)

                            cratesLoaded = cratesLoaded + 1

                            Utils.ShowNotification(
                                string.format(Config.Notifications.crateLoaded,
                                    cratesLoaded, totalCrates),
                                'success'
                            )
                            NUI({ action = 'updateObjective', key = 'load_crates', completed = false,
                                  counter = cratesLoaded, total = totalCrates })

                            if cratesLoaded >= totalCrates then
                                Utils.ShowNotification(Config.Notifications.allCratesLoaded, 'success')
                                NUI({ action = 'updateObjective', key = 'load_crates', completed = true,
                                      counter = totalCrates, total = totalCrates })
                                jobPhase = 'go_scale'
                                SetupScaleInteraction()
                                return
                            end
                        end
                    end
                end

                Wait(0)
            else
                -- Find nearest unloaded crate on the ground
                local nearestObj  = nil
                local nearestDist = Config.GroupMode.cratePickupDistance

                for _, obj in pairs(farmCrateObjs) do
                    if obj and DoesEntityExist(obj) then
                        local d = #(pedCoords - GetEntityCoords(obj))
                        if d < nearestDist then
                            nearestDist = d
                            nearestObj  = obj
                        end
                    end
                end

                if nearestObj then
                    local objCoords = GetEntityCoords(nearestObj)
                    Utils.DrawText3D(objCoords.x, objCoords.y, objCoords.z + 0.7,
                        Config.Notifications.pressEPickup)

                    if IsControlJustReleased(0, 38) then  -- E key
                        -- Remove from ground list
                        for i, obj in pairs(farmCrateObjs) do
                            if obj == nearestObj then
                                farmCrateObjs[i] = nil
                                break
                            end
                        end

                        -- Attach to player right-hand bone
                        isCarryingCrate = true
                        carryCrateObj   = nearestObj

                        Utils.LoadAnimDict(Config.GroupMode.crateCarryAnimDict)
                        TaskPlayAnim(ped,
                            Config.GroupMode.crateCarryAnimDict,
                            Config.GroupMode.crateCarryAnimName,
                            8.0, -8.0, -1, 49, 0, false, false, false)

                        AttachEntityToEntity(
                            carryCrateObj, ped,
                            GetPedBoneIndex(ped, Config.GroupMode.crateAttachBone),
                            Config.GroupMode.crateAttachOffset.x,
                            Config.GroupMode.crateAttachOffset.y,
                            Config.GroupMode.crateAttachOffset.z,
                            Config.GroupMode.crateAttachRotation.x,
                            Config.GroupMode.crateAttachRotation.y,
                            Config.GroupMode.crateAttachRotation.z,
                            true, true, false, true, 2, true
                        )

                        Utils.ShowNotification(Config.Notifications.cratePickedUp, 'inform')
                    end

                    Wait(0)
                else
                    Wait(Config.JobCheckIntervalNear)
                end
            end
        end
    end)
end

-- =========================================================================
-- SOLO MODE — NPC LOADING
-- =========================================================================
local function StartSoloLoading()
    if not currentTruck or not DoesEntityExist(currentTruck) then
        Utils.ShowNotification(Config.Notifications.truckNotSpawned, 'error')
        Cleanup()
        return
    end

    jobPhase     = 'loading'
    local rounds = math.random(Config.SoloMode.loadRounds, Config.SoloMode.loadRoundsMax)
    totalCrates  = rounds
    cratesLoaded = 0

    NUI({ action = 'updateObjective', key = 'load_crates', completed = false,
          counter = 0, total = totalCrates })
    Utils.ShowNotification(Config.Notifications.npcLoading, 'inform')

    -- Spawn worker NPCs near the truck
    local npcList    = {}
    local truckCoords = GetEntityCoords(currentTruck)

    for i = 1, Config.SoloMode.npcCount do
        local off   = Config.SoloMode.npcPickupOffsets[i] or vector3(0.0, i * 2.0, 0.0)
        local spawn = vector3(truckCoords.x + off.x, truckCoords.y + off.y, truckCoords.z + off.z)
        npcList[i]  = Utils.CreateNPC(Config.SoloMode.npcModel, spawn, 0.0)
    end

    -- Simulate timed loading rounds
    CreateThread(function()
        for round = 1, rounds do
            if not jobActive then break end

            -- Start carry animation on all workers
            for _, npc in ipairs(npcList) do
                if DoesEntityExist(npc) then
                    Utils.LoadAnimDict(Config.SoloMode.crateCarryAnimDict)
                    TaskPlayAnim(npc,
                        Config.SoloMode.crateCarryAnimDict,
                        Config.SoloMode.crateCarryAnimName,
                        8.0, -8.0, -1, 49, 0, false, false, false)
                end
            end

            -- Spawn a visual crate prop near the truck
            local slot      = Config.SoloMode.crateOnTruckOffsets[round] or vector3(0.0, -1.5, 0.05)
            local spawnPos  = vector3(
                truckCoords.x + slot.x,
                truckCoords.y + slot.y,
                truckCoords.z + slot.z + 1.2   -- start slightly above so it drops in
            )
            local crateObj  = Utils.SpawnProp(Config.SoloMode.crateProp, spawnPos, false)

            Wait(Config.SoloMode.timePerRound)

            if not jobActive then
                Utils.DeleteEntity(crateObj)
                break
            end

            -- Attach crate to truck chassis
            if DoesEntityExist(crateObj) and DoesEntityExist(currentTruck) then
                AttachEntityToEntity(
                    crateObj, currentTruck,
                    GetEntityBoneIndexByName(currentTruck, 'chassis'),
                    slot.x, slot.y, slot.z,
                    0.0, 0.0, 0.0,
                    false, false, false, false, 2, true
                )
            end

            -- Stop NPCs briefly between rounds
            for _, npc in ipairs(npcList) do
                if DoesEntityExist(npc) then ClearPedTasks(npc) end
            end

            cratesLoaded = cratesLoaded + 1
            NUI({ action = 'updateObjective', key = 'load_crates', completed = false,
                  counter = cratesLoaded, total = totalCrates })
        end

        -- Clean up NPCs
        for _, npc in ipairs(npcList) do
            Utils.DeleteEntity(npc)
        end

        if not jobActive then return end

        Utils.ShowNotification(Config.Notifications.npcLoadComplete, 'success')
        NUI({ action = 'updateObjective', key = 'load_crates', completed = true,
              counter = totalCrates, total = totalCrates })

        jobPhase = 'go_scale'
        SetupScaleInteraction()
    end)
end

-- =========================================================================
-- FARM ARRIVAL WATCHER
-- =========================================================================
local function WatchFarmArrival()
    CreateThread(function()
        local notified = false

        while jobActive and jobPhase == 'go_farm' do
            local ped  = PlayerPedId()
            local dist = #(GetEntityCoords(ped) - Config.Farm.coords)

            if dist < Config.Farm.arrivalDistance then
                if not notified then
                    notified = true
                    jobPhase = 'at_farm'

                    Utils.ShowNotification(Config.Notifications.arrivedAtFarm, 'success')
                    NUI({ action = 'updateObjective', key = 'go_farm', completed = true })

                    if farmBlip and DoesBlipExist(farmBlip) then
                        SetBlipRoute(farmBlip, false)
                    end

                    -- Mode selection menu
                    lib.registerContext({
                        id      = 'fetchq_mode_choice',
                        title   = Config.Notifications.soloChoice,
                        options = {
                            {
                                title       = '🧍 Solo Transport',
                                description = 'Workers load the truck automatically.',
                                icon        = 'person',
                                onSelect    = function()
                                    jobMode = 'solo'
                                    StartSoloLoading()
                                end,
                            },
                            {
                                title       = '👥 Group Transport',
                                description = 'Manually load crates onto the truck with your team.',
                                icon        = 'people-group',
                                onSelect    = function()
                                    jobMode = 'group'
                                    StartGroupLoading()
                                end,
                            },
                        },
                    })
                    lib.showContext('fetchq_mode_choice')
                    return
                end
            end

            if dist < Config.NearDistance then
                Wait(Config.JobCheckIntervalNear)
            else
                Wait(Config.JobCheckInterval)
            end
        end
    end)
end

-- =========================================================================
-- TRUCK HEALTH & DISTANCE WATCHDOG
-- =========================================================================
local function StartTruckWatchdog()
    CreateThread(function()
        while jobActive do
            if not currentTruck or not DoesEntityExist(currentTruck) then
                Utils.ShowNotification(Config.Notifications.truckDestroyed, 'error')
                Cleanup()
                return
            end

            if GetEntityHealth(currentTruck) <= 0 then
                Utils.ShowNotification(Config.Notifications.truckDestroyed, 'error')
                Cleanup()
                return
            end

            -- Only enforce distance after job is underway
            if jobPhase ~= 'idle' and jobPhase ~= 'at_farm' and jobPhase ~= 'done' then
                local ped  = PlayerPedId()
                local dist = #(GetEntityCoords(ped) - GetEntityCoords(currentTruck))
                if dist > Config.MaxDistanceFromTruck then
                    Utils.ShowNotification(Config.Notifications.tooFarFromTruck, 'error')
                    Cleanup()
                    return
                end
            end

            Wait(Config.JobCheckInterval)
        end
    end)
end

-- =========================================================================
-- START JOB
-- =========================================================================
local function StartJob()
    if jobActive then
        Utils.ShowNotification(Config.Notifications.jobAlreadyActive, 'error')
        return
    end

    -- Pre-select delivery points so total is known for the HUD immediately
    deliveryPoints  = SelectDeliveryPoints()
    deliveriesTotal = #deliveryPoints
    deliveriesDone  = 0

    -- Spawn truck
    local spawnCoord = Config.Truck.spawnCoord
    currentTruck = Utils.SpawnVehicle(Config.Truck.model, spawnCoord)

    if not currentTruck or not DoesEntityExist(currentTruck) then
        Utils.ShowNotification(Config.Notifications.truckNotSpawned, 'error')
        return
    end

    -- Attach a blip to the truck entity
    truckBlip = AddBlipForEntity(currentTruck)
    SetBlipSprite(truckBlip, 18)
    SetBlipColour(truckBlip, 3)
    SetBlipScale(truckBlip, 0.9)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('Your Truck')
    EndTextCommandSetBlipName(truckBlip)

    -- Activate job state
    jobActive  = true
    jobPhase   = 'go_farm'
    jobMode    = nil
    docType    = nil
    cratesLoaded = 0

    Utils.ShowNotification(Config.Notifications.jobAccepted, 'success')

    -- Show initial objectives HUD
    NUI({
        action = 'showObjectives',
        objectives = {
            { key = 'go_farm',      text = 'Go to the farm',            completed = false },
            { key = 'load_crates',  text = 'Load the crates',           completed = false },
            { key = 'get_document', text = 'Get transport certificate',  completed = false },
            { key = 'deliver',      text = 'Deliver the cargo',          completed = false,
              counter = 0, total = deliveriesTotal },
        },
    })

    -- Route GPS to farm
    if farmBlip and DoesBlipExist(farmBlip) then
        SetBlipRoute(farmBlip, true)
    end

    WatchFarmArrival()
    StartTruckWatchdog()
end

-- =========================================================================
-- INITIALISATION  — runs once on resource start
-- =========================================================================
CreateThread(function()
    -- Depot blip
    depotBlip = Utils.CreateBlip(
        vector3(Config.DepotNPC.coords.x, Config.DepotNPC.coords.y, Config.DepotNPC.coords.z),
        Config.DepotNPC.blip.sprite,
        Config.DepotNPC.blip.color,
        Config.DepotNPC.blip.scale,
        Config.DepotNPC.blip.label
    )

    -- Farm blip
    farmBlip = Utils.CreateBlip(
        Config.Farm.coords,
        Config.Farm.blip.sprite,
        Config.Farm.blip.color,
        Config.Farm.blip.scale,
        Config.Farm.blip.label
    )

    -- Weigh station blip
    scaleBlip = Utils.CreateBlip(
        Config.Scale.coords,
        Config.Scale.blip.sprite,
        Config.Scale.blip.color,
        Config.Scale.blip.scale,
        Config.Scale.blip.label
    )

    -- Depot NPC
    depotNpc = Utils.CreateNPC(
        Config.DepotNPC.model,
        Config.DepotNPC.coords,
        Config.DepotNPC.coords.w
    )

    Wait(500)  -- let the NPC entity stabilise before registering targets

    -- Attach interaction to the depot NPC
    if HasOxTarget() then
        exports.ox_target:addLocalEntity(depotNpc, {
            {
                name     = 'fetchq_start_job',
                icon     = 'fas fa-truck',
                label    = 'Start Fruit Transport',
                distance = Config.DepotNPC.interactDistance,
                onSelect = function()
                    StartJob()
                end,
            },
        })

    elseif HasQBTarget() then
        exports['qb-target']:AddTargetEntity(depotNpc, {
            options = {
                {
                    icon   = 'fas fa-truck',
                    label  = 'Start Fruit Transport',
                    action = function()
                        StartJob()
                    end,
                },
            },
            distance = Config.DepotNPC.interactDistance,
        })

    else
        -- Fallback: DrawText3D + E key proximity on the depot NPC
        CreateThread(function()
            while true do
                local ped   = PlayerPedId()
                local dist  = #(GetEntityCoords(ped) - GetEntityCoords(depotNpc))

                if dist < Config.DepotNPC.interactDistance then
                    Utils.DrawText3D(
                        Config.DepotNPC.coords.x,
                        Config.DepotNPC.coords.y,
                        Config.DepotNPC.coords.z + 1.2,
                        Config.Notifications.pressEStartJob
                    )
                    if IsControlJustReleased(0, 38) then
                        StartJob()
                    end
                    Wait(0)
                else
                    Wait(Config.JobCheckInterval)
                end
            end
        end)
    end
end)

-- =========================================================================
-- NUI CALLBACKS
-- =========================================================================

-- Called by script.js when the document overlay is closed by the player
RegisterNUICallback('closeDocument', function(_, cb)
    cb({})
end)

-- =========================================================================
-- CLIENT EVENTS
-- =========================================================================

--- External cancellation (e.g. admin command, another resource)
AddEventHandler('fetchq-fruitjob:client:CancelJob', function()
    if jobActive then
        Utils.ShowNotification(Config.Notifications.jobCancelled, 'error')
        Cleanup()
    end
end)

--- Police checkpoint event — called by a police script that checks the player's document
AddEventHandler('fetchq-fruitjob:client:PoliceCheck', function()
    if not jobActive or not docType then return end

    if docType == Config.Documents.green then
        Utils.ShowNotification(Config.Notifications.policeCheckGreen, 'success')
        NUI({ action = 'showDocument', type = 'green', autoClose = true })
    elseif docType == Config.Documents.red then
        Utils.ShowNotification(Config.Notifications.policeCheckRed, 'error')
        NUI({ action = 'showDocument', type = 'red', autoClose = true })
    end
end)