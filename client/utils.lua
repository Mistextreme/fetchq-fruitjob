-- =========================================================================
-- client/utils.lua
-- Funções utilitárias partilhadas para o client-side do script de transportes
-- =========================================================================

Utils = {}

--- Carrega um modelo (Ped, Veículo ou Prop) de forma síncrona
--- @param model string|number Nome ou Hash do modelo
--- @return number hash Retorna o hash gerado
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

--- Carrega um dicionário de animação de forma síncrona
--- @param dict string Nome do dicionário de animação
function Utils.LoadAnimDict(dict)
    if not HasAnimDictLoaded(dict) then
        RequestAnimDict(dict)
        while not HasAnimDictLoaded(dict) do
            Wait(10)
        end
    end
end

--- Cria um NPC estático (ex: NPC do armazém, pontos de entrega)
--- @param model string Modelo do NPC
--- @param coords vector3|vector4 Coordenadas onde o NPC vai aparecer
--- @param heading number Rotação (heading) do NPC
--- @return number ped Entidade do NPC criado
function Utils.CreateNPC(model, coords, heading)
    local hash = Utils.LoadModel(model)
    local zCoord = type(coords) == "vector4" and coords.z or coords.z
    local yCoord = type(coords) == "vector4" and coords.y or coords.y
    local xCoord = type(coords) == "vector4" and coords.x or coords.x
    local pedHeading = type(coords) == "vector4" and coords.w or heading
    
    local ped = CreatePed(4, hash, xCoord, yCoord, zCoord - 1.0, pedHeading, false, true)
    
    SetEntityHeading(ped, pedHeading)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetModelAsNoLongerNeeded(hash)
    
    return ped
end

--- Cria e configura um blip no mapa
--- @param coords vector3 Coordenadas do Blip
--- @param sprite number Ícone do blip
--- @param color number Cor do blip
--- @param scale number Tamanho do blip
--- @param label string Nome do blip no mapa
--- @return number blip ID do blip
function Utils.CreateBlip(coords, sprite, color, scale, label)
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    
    SetBlipSprite(blip, sprite)
    SetBlipColour(blip, color)
    SetBlipScale(blip, scale)
    SetBlipAsShortRange(blip, true)
    
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(label)
    EndTextCommandSetBlipName(blip)
    
    return blip
end

--- Cria um veículo (Camião de Transporte)
--- @param model string Modelo do veículo
--- @param coords vector4 Coordenadas e Heading onde o veículo vai spawnar
--- @return number vehicle Entidade do veículo criado
function Utils.SpawnVehicle(model, coords)
    local hash = Utils.LoadModel(model)
    local vehicle = CreateVehicle(hash, coords.x, coords.y, coords.z, coords.w, true, false)
    
    SetEntityAsMissionEntity(vehicle, true, true)
    SetVehicleHasBeenOwnedByPlayer(vehicle, true)
    SetVehicleNeedsToBeHotwired(vehicle, false)
    SetModelAsNoLongerNeeded(hash)
    
    return vehicle
end

--- Cria um objeto (Caixas de fruta)
--- @param model string Modelo do objeto
--- @param coords vector3 Coordenadas
--- @param isNetworked boolean Se deve ser sincronizado na rede (para grupos)
--- @return number prop Entidade do objeto criado
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

--- Reproduz uma animação num ped
--- @param ped number Entidade do ped
--- @param dict string Dicionário da animação
--- @param name string Nome da animação
--- @param flag number Flag da animação (ex: 49 para andar enquanto anima)
function Utils.PlayAnim(ped, dict, name, flag)
    Utils.LoadAnimDict(dict)
    TaskPlayAnim(ped, dict, name, 8.0, -8.0, -1, flag or 49, 0, false, false, false)
    RemoveAnimDict(dict)
end

--- Apaga uma entidade de forma segura (Veículo, NPC ou Prop)
--- @param entity number Entidade a ser apagada
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

--- Apresenta uma notificação usando o ox_lib
--- @param msg string Mensagem a exibir
--- @param msgType string Tipo (success, error, inform)
function Utils.ShowNotification(msg, msgType)
    lib.notify({
        title = 'Transporte de Fruta',
        description = msg,
        type = msgType or 'inform',
        position = 'top-right'
    })
end

--- Desenha texto 3D no mundo (Fallback para locais onde não haja target)
--- @param x number
--- @param y number
--- @param z number
--- @param text string Texto a mostrar
function Utils.DrawText3D(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    if onScreen then
        SetTextScale(0.35, 0.35)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextColour(255, 255, 255, 215)
        SetTextEntry("STRING")
        SetTextCentre(1)
        AddTextComponentString(text)
        DrawText(_x, _y)
        local factor = (string.len(text)) / 370
        DrawRect(_x, _y + 0.0125, 0.015 + factor, 0.03, 41, 11, 41, 68)
    end
end