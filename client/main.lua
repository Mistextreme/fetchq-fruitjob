-- =========================================================================
-- client/main.lua
-- Lógica principal do cliente para o sistema de transporte de fruta
-- =========================================================================

local jobData = {
    active = false,
    isGroup = false,
    phase = nil,
    truck = nil,
    cratesLoaded = 0,
    deliveries = 0,
    maxDeliveries = 0,
    deliveryPoints = {},
    blips = {},
    entities = {},
    carryingCrate = false,
    crateProp = nil
}

-- =========================================================================
-- FUNÇÕES DE LIMPEZA E GESTÃO
-- =========================================================================

local function CleanupJob()
    jobData.active = false
    jobData.phase = nil
    jobData.cratesLoaded = 0
    jobData.deliveries = 0
    jobData.carryingCrate = false

    -- Limpar UI
    SendNUIMessage({ action = 'hideObjectives' })
    SendNUIMessage({ action = 'hideDocument' })

    -- Remover blips temporários
    for _, blip in ipairs(jobData.blips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    jobData.blips = {}

    -- Remover entidades temporárias (Camião, NPCs de entrega, caixas)
    for _, entity in ipairs(jobData.entities) do
        Utils.DeleteEntity(entity)
    end
    jobData.entities = {}

    if jobData.truck and DoesEntityExist(jobData.truck) then
        Utils.DeleteEntity(jobData.truck)
    end
    jobData.truck = nil

    if jobData.crateProp and DoesEntityExist(jobData.crateProp) then
        Utils.DeleteEntity(jobData.crateProp)
    end
    jobData.crateProp = nil

    -- Limpar targets
    exports.ox_target:removeZone('fruitjob_scale')
    exports.ox_target:removeModel(Config.GroupMode.crateProp, {'fruitjob_pickup_crate'})
end

local function FailJob(reason)
    if not jobData.active then return end
    Utils.ShowNotification(reason, 'error')
    CleanupJob()
end

-- =========================================================================
-- FASE 4: ENTREGAS
-- =========================================================================

local function CompleteDelivery(index)
    jobData.deliveries = jobData.deliveries + 1
    
    -- Atualizar NUI
    SendNUIMessage({ 
        action = 'updateObjective', 
        key = 'deliver', 
        counter = jobData.deliveries, 
        total = jobData.maxDeliveries 
    })

    Utils.ShowNotification(string.format(Config.Notifications.deliveryComplete, jobData.deliveries, jobData.maxDeliveries), 'success')
    
    -- Remover o NPC específico e o seu blip
    local point = jobData.deliveryPoints[index]
    if point.ped and DoesEntityExist(point.ped) then
        Utils.DeleteEntity(point.ped)
    end
    if point.blip and DoesBlipExist(point.blip) then
        RemoveBlip(point.blip)
    end
    point.done = true

    -- Verificar se terminou tudo
    if jobData.deliveries >= jobData.maxDeliveries then
        Utils.ShowNotification(Config.Notifications.allDeliveriesComplete, 'success')
        SendNUIMessage({ action = 'updateObjective', key = 'deliver', completed = true })
        
        -- Chamar servidor para pagamento
        TriggerServerEvent('fetchq-fruitjob:server:FinishJob', jobData.documentType)
        
        Wait(2000)
        CleanupJob()
    end
end

local function StartDeliveries()
    jobData.phase = 'deliver'
    jobData.maxDeliveries = Config.DeliveryPoints.count
    jobData.deliveries = 0

    -- Atualizar NUI
    SendNUIMessage({ action = 'updateObjective', key = 'get_document', completed = true })
    SendNUIMessage({ 
        action = 'updateObjective', 
        key = 'deliver', 
        counter = 0, 
        total = jobData.maxDeliveries 
    })
    
    Utils.ShowNotification(string.format(Config.Notifications.deliveryStart, jobData.maxDeliveries), 'inform')

    -- Escolher pontos aleatórios
    local allLocations = Config.DeliveryPoints.locations
    local selectedIndexes = {}
    
    while #selectedIndexes < jobData.maxDeliveries do
        local rand = math.random(1, #allLocations)
        local alreadySelected = false
        for _, v in ipairs(selectedIndexes) do
            if v == rand then alreadySelected = true break end
        end
        if not alreadySelected then
            table.insert(selectedIndexes, rand)
        end
    end

    -- Criar NPCs e Blips para os pontos escolhidos
    for i, idx in ipairs(selectedIndexes) do
        local loc = allLocations[idx]
        local ped = Utils.CreateNPC(Config.DeliveryNPC.model, loc.npcSpawn, loc.npcSpawn.w)
        local blip = Utils.CreateBlip(loc.coords, Config.DeliveryPoints.blip.sprite, Config.DeliveryPoints.blip.color, Config.DeliveryPoints.blip.scale, loc.label)
        
        table.insert(jobData.entities, ped)
        table.insert(jobData.blips, blip)
        
        jobData.deliveryPoints[i] = {
            index = i,
            loc = loc,
            ped = ped,
            blip = blip,
            done = false
        }

        -- Adicionar Target ao NPC
        exports.ox_target:addLocalEntity(ped, {
            {
                name = 'fruitjob_deliver_'..i,
                icon = 'fas fa-box',
                label = string.format(Config.Notifications.pressEDeliver, ""),
                distance = Config.DeliveryNPC.truckApproachDist,
                canInteract = function()
                    return jobData.active and jobData.phase == 'deliver' and not jobData.deliveryPoints[i].done
                end,
                onSelect = function()
                    -- Distância do camião
                    local truckCoords = GetEntityCoords(jobData.truck)
                    local pedCoords = GetEntityCoords(ped)
                    if #(truckCoords - pedCoords) > 15.0 then
                        Utils.ShowNotification("O camião está muito longe!", "error")
                        return
                    end
                    
                    if lib.progressCircle({
                        duration = Config.DeliveryPoints.deliveryProgressTime,
                        position = 'bottom',
                        useWhileDead = false,
                        canCancel = true,
                        disable = { move = true, car = true, combat = true },
                        anim = { dict = 'anim@heists@box_carry@', clip = 'idle' },
                        prop = { model = Config.DeliveryNPC.crateProp, bone = 28422, pos = vector3(0.0, 0.0, 0.0), rot = vector3(0.0, 0.0, 0.0) }
                    }) then
                        CompleteDelivery(i)
                    end
                end
            }
        })
    end
end

-- =========================================================================
-- FASE 3: BÁSCULA E DOCUMENTOS
-- =========================================================================

local function IssueDocument(docType)
    jobData.documentType = docType
    
    -- Pedir documento ao servidor
    TriggerServerEvent('fetchq-fruitjob:server:GiveDocument', docType)
    
    -- Animação UI
    SendNUIMessage({ 
        action = 'showCertificate', 
        type = docType == Config.Documents.green and 'green' or 'red' 
    })
    
    Utils.ShowNotification(Config.Notifications.documentReceived, 'success')
    Wait(5000) -- Esperar que a UI termine a animação
    
    StartDeliveries()
end

local function SetupScalePhase()
    jobData.phase = 'scale'
    SendNUIMessage({ action = 'updateObjective', key = 'load_crates', completed = true })
    Utils.ShowNotification(Config.Notifications.allCratesLoaded, 'inform')
    
    -- Target na Báscula
    exports.ox_target:addSphereZone({
        coords = Config.Scale.coords,
        radius = Config.Scale.interactDistance,
        debug = Config.Debug,
        name = 'fruitjob_scale',
        options = {
            {
                name = 'fruitjob_use_scale',
                icon = 'fas fa-balance-scale',
                label = string.format(Config.Notifications.pressEScale, ""),
                canInteract = function()
                    return jobData.active and jobData.phase == 'scale'
                end,
                onSelect = function()
                    if GetVehiclePedIsIn(PlayerPedId(), false) ~= jobData.truck then
                        Utils.ShowNotification("Tens de estar dentro do camião de transporte!", "error")
                        return
                    end

                    lib.registerContext({
                        id = 'fruitjob_document_menu',
                        title = Config.MenuTexts.riskTitle,
                        options = {
                            {
                                title = Config.MenuTexts.safeOption,
                                description = Config.MenuTexts.safeDescription,
                                icon = 'file-shield',
                                iconColor = '#228B22',
                                onSelect = function() IssueDocument(Config.Documents.green) end
                            },
                            {
                                title = Config.MenuTexts.riskyOption,
                                description = Config.MenuTexts.riskyDescription,
                                icon = 'file-circle-exclamation',
                                iconColor = '#C81E1E',
                                onSelect = function() IssueDocument(Config.Documents.red) end
                            }
                        }
                    })
                    lib.showContext('fruitjob_document_menu')
                end
            }
        }
    })
end

-- =========================================================================
-- FASE 2: CARREGAMENTO
-- =========================================================================

local function HandleGroupLoading()
    jobData.phase = 'loading'
    local maxCrates = Config.SoloMode.loadRoundsMax -- Usado também para group mode
    
    -- Spawn Caixas
    for i, pos in ipairs(Config.GroupMode.cratePositions) do
        local crate = Utils.SpawnProp(Config.GroupMode.crateProp, pos, false)
        table.insert(jobData.entities, crate)
        PlaceObjectOnGroundProperly(crate)
        
        exports.ox_target:addLocalEntity(crate, {
            {
                name = 'fruitjob_pickup_crate_'..i,
                icon = 'fas fa-hand-holding',
                label = string.format(Config.Notifications.pressEPickup, ""),
                distance = Config.GroupMode.cratePickupDistance,
                canInteract = function()
                    return jobData.active and jobData.phase == 'loading' and not jobData.carryingCrate
                end,
                onSelect = function()
                    if jobData.carryingCrate then return end
                    jobData.carryingCrate = true
                    
                    Utils.PlayAnim(PlayerPedId(), Config.GroupMode.crateCarryAnimDict, Config.GroupMode.crateCarryAnimName, 49)
                    
                    -- Prender caixa à mão
                    local hash = Utils.LoadModel(Config.GroupMode.crateProp)
                    jobData.crateProp = CreateObject(hash, 0, 0, 0, true, true, false)
                    AttachEntityToEntity(jobData.crateProp, PlayerPedId(), GetPedBoneIndex(PlayerPedId(), Config.GroupMode.crateAttachBone), Config.GroupMode.crateAttachOffset.x, Config.GroupMode.crateAttachOffset.y, Config.GroupMode.crateAttachOffset.z, Config.GroupMode.crateAttachRotation.x, Config.GroupMode.crateAttachRotation.y, Config.GroupMode.crateAttachRotation.z, true, true, false, true, 1, true)
                    
                    Utils.DeleteEntity(crate) -- Apagar do chão
                    Utils.ShowNotification(Config.Notifications.cratePickedUp, 'inform')
                end
            }
        })
    end

    -- Target na traseira do camião para guardar
    exports.ox_target:addLocalEntity(jobData.truck, {
        {
            name = 'fruitjob_load_truck',
            icon = 'fas fa-truck-loading',
            label = string.format(Config.Notifications.pressELoad, ""),
            distance = 3.0,
            canInteract = function()
                return jobData.active and jobData.phase == 'loading' and jobData.carryingCrate
            end,
            onSelect = function()
                if not jobData.carryingCrate then return end
                
                if lib.progressCircle({
                    duration = Config.GroupMode.loadProgressTime,
                    position = 'bottom',
                    useWhileDead = false,
                    canCancel = true,
                    disable = { move = true, car = true, combat = true },
                }) then
                    jobData.carryingCrate = false
                    ClearPedTasks(PlayerPedId())
                    Utils.DeleteEntity(jobData.crateProp)
                    jobData.crateProp = nil
                    
                    jobData.cratesLoaded = jobData.cratesLoaded + 1
                    
                    SendNUIMessage({ 
                        action = 'updateObjective', 
                        key = 'load_crates', 
                        counter = jobData.cratesLoaded, 
                        total = maxCrates 
                    })
                    
                    Utils.ShowNotification(string.format(Config.Notifications.crateLoaded, jobData.cratesLoaded, maxCrates), 'success')
                    
                    if jobData.cratesLoaded >= maxCrates then
                        exports.ox_target:removeLocalEntity(jobData.truck, {'fruitjob_load_truck'})
                        SetupScalePhase()
                    end
                end
            end
        }
    })
end

local function HandleSoloLoading()
    jobData.phase = 'loading'
    local maxCrates = Config.SoloMode.loadRoundsMax
    
    Utils.ShowNotification(Config.Notifications.npcLoading, 'inform')
    
    CreateThread(function()
        for i = 1, maxCrates do
            if not jobData.active or jobData.phase ~= 'loading' then break end
            
            -- Simulação de carregamento (simplificada para robustez)
            Wait(Config.SoloMode.timePerRound / 2)
            
            jobData.cratesLoaded = jobData.cratesLoaded + 1
            SendNUIMessage({ 
                action = 'updateObjective', 
                key = 'load_crates', 
                counter = jobData.cratesLoaded, 
                total = maxCrates 
            })
            
            Utils.ShowNotification(string.format(Config.Notifications.crateLoaded, jobData.cratesLoaded, maxCrates), 'inform')
            Wait(Config.SoloMode.timePerRound / 2)
        end
        
        if jobData.active and jobData.cratesLoaded >= maxCrates then
            SetupScalePhase()
        end
    end)
end

-- =========================================================================
-- FASE 1: QUINTA E DISTÂNCIAS
-- =========================================================================

local function StartJobMonitor()
    CreateThread(function()
        while jobData.active do
            Wait(Config.JobCheckInterval)
            
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            
            -- Verificar distância do camião
            if jobData.truck and DoesEntityExist(jobData.truck) then
                local truckCoords = GetEntityCoords(jobData.truck)
                if #(coords - truckCoords) > Config.MaxDistanceFromTruck then
                    FailJob(Config.Notifications.tooFarFromTruck)
                    break
                end
                
                if GetEntityHealth(jobData.truck) == 0 or not IsVehicleDriveable(jobData.truck, false) then
                    FailJob(Config.Notifications.truckDestroyed)
                    break
                end
            end
            
            -- Lógica de Chegada à Quinta
            if jobData.phase == 'farm' then
                if #(coords - Config.Farm.coords) < Config.Farm.arrivalDistance then
                    Utils.ShowNotification(Config.Notifications.arrivedAtFarm, 'success')
                    SendNUIMessage({ action = 'updateObjective', key = 'go_farm', completed = true })
                    
                    if jobData.isGroup then
                        Utils.ShowNotification(Config.Notifications.groupCrateInfo, 'inform')
                        HandleGroupLoading()
                    else
                        HandleSoloLoading()
                    end
                end
            end
        end
    end)
end

local function StartJob(isGroup)
    if jobData.active then
        Utils.ShowNotification(Config.Notifications.jobAlreadyActive, 'error')
        return
    end

    jobData.active = true
    jobData.isGroup = isGroup
    jobData.phase = 'farm'
    jobData.cratesLoaded = 0
    jobData.deliveries = 0
    jobData.maxDeliveries = Config.SoloMode.loadRoundsMax

    -- Spawn Truck
    local spawnIndex = math.random(1, #Config.Truck.spawnCoords)
    jobData.truck = Utils.SpawnVehicle(Config.Truck.model, Config.Truck.spawnCoords[spawnIndex])
    
    if not jobData.truck or not DoesEntityExist(jobData.truck) then
        FailJob(Config.Notifications.truckNotSpawned)
        return
    end

    TaskWarpPedIntoVehicle(PlayerPedId(), jobData.truck, -1)
    
    -- Iniciar UI NUI
    SendNUIMessage({ 
        action = 'showObjectives',
        objectives = {
            { key = 'go_farm' },
            { key = 'load_crates', total = jobData.maxDeliveries },
            { key = 'get_document' },
            { key = 'deliver' }
        }
    })
    
    Utils.ShowNotification(Config.Notifications.jobAccepted, 'success')
    StartJobMonitor()
end

-- =========================================================================
-- INICIALIZAÇÃO E TARGETS ESTÁTICOS
-- =========================================================================

CreateThread(function()
    -- Criar Blips Permanentes (Quinta e Báscula)
    Utils.CreateBlip(Config.Farm.coords, Config.Farm.blip.sprite, Config.Farm.blip.color, Config.Farm.blip.scale, Config.Farm.blip.label)
    Utils.CreateBlip(Config.Scale.coords, Config.Scale.blip.sprite, Config.Scale.blip.color, Config.Scale.blip.scale, Config.Scale.blip.label)

    -- Criar NPC do Depot e respectivo Blip
    local depot = Config.DepotNPC
    Utils.CreateBlip(depot.coords, depot.blip.sprite, depot.blip.color, depot.blip.scale, depot.blip.label)
    
    local depotPed = Utils.CreateNPC(depot.model, depot.coords, depot.coords.w)
    
    exports.ox_target:addLocalEntity(depotPed, {
        {
            name = 'fruitjob_start_depot',
            icon = 'fas fa-clipboard-list',
            label = string.format(Config.Notifications.pressEStartJob, ""),
            distance = depot.interactDistance,
            onSelect = function()
                if jobData.active then
                    lib.registerContext({
                        id = 'fruitjob_cancel_menu',
                        title = 'Fruit Transport',
                        options = {
                            {
                                title = 'Cancel Job',
                                description = 'Stop current transport job.',
                                icon = 'xmark',
                                iconColor = 'red',
                                onSelect = function() 
                                    FailJob(Config.Notifications.jobCancelled) 
                                end
                            }
                        }
                    })
                    lib.showContext('fruitjob_cancel_menu')
                    return
                end

                lib.registerContext({
                    id = 'fruitjob_start_menu',
                    title = 'Fruit Transport',
                    options = {
                        {
                            title = 'Solo Transport',
                            description = 'Automated loading by NPC workers.',
                            icon = 'user',
                            onSelect = function() StartJob(false) end
                        },
                        {
                            title = 'Group Transport',
                            description = 'Load crates manually with your group.',
                            icon = 'users',
                            onSelect = function() StartJob(true) end
                        }
                    }
                })
                lib.showContext('fruitjob_start_menu')
            end
        }
    })
end)

-- =========================================================================
-- NUI CALLBACKS
-- =========================================================================

RegisterNUICallback('closeDocument', function(data, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)