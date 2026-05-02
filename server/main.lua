-- =========================================================================
-- server/main.lua
-- Lógica do servidor para o sistema de transporte de fruta
-- =========================================================================

local QBCore = nil
local ESX = nil

-- =========================================================================
-- DETEÇÃO DE FRAMEWORK AUTOMÁTICA
-- =========================================================================

if GetResourceState('qb-core') == 'started' then
    QBCore = exports['qb-core']:GetCoreObject()
elseif GetResourceState('es_extended') == 'started' then
    ESX = exports['es_extended']:getSharedObject()
end

-- =========================================================================
-- FUNÇÕES UTILITÁRIAS DO SERVIDOR
-- =========================================================================

--- Função para adicionar dinheiro ao jogador de forma compatível
local function AddMoney(source, amount, account)
    if QBCore then
        local Player = QBCore.Functions.GetPlayer(source)
        if Player then
            Player.Functions.AddMoney(account or 'cash', amount, "fruit-transport-job")
        end
    elseif ESX then
        local xPlayer = ESX.GetPlayerFromId(source)
        if xPlayer then
            -- Mapeia 'cash' para 'money' no ESX, que é o padrão
            local esxAccount = account == 'cash' and 'money' or account
            xPlayer.addAccountMoney(esxAccount, amount)
        end
    else
        -- Fallback nativo caso se use ox_inventory sem framework clássica
        local itemAccount = account == 'cash' and 'money' or account
        exports.ox_inventory:AddItem(source, itemAccount, amount)
    end
end

--- Função para dar um item (Documentos)
local function AddItem(source, item, amount)
    if GetResourceState('ox_inventory') == 'started' then
        exports.ox_inventory:AddItem(source, item, amount)
    elseif QBCore then
        local Player = QBCore.Functions.GetPlayer(source)
        if Player then
            Player.Functions.AddItem(item, amount)
        end
    elseif ESX then
        local xPlayer = ESX.GetPlayerFromId(source)
        if xPlayer then
            xPlayer.addInventoryItem(item, amount)
        end
    end
end

--- Função para remover um item (Documentos no final do serviço)
local function RemoveItem(source, item, amount)
    if GetResourceState('ox_inventory') == 'started' then
        exports.ox_inventory:RemoveItem(source, item, amount)
    elseif QBCore then
        local Player = QBCore.Functions.GetPlayer(source)
        if Player then
            Player.Functions.RemoveItem(item, amount)
        end
    elseif ESX then
        local xPlayer = ESX.GetPlayerFromId(source)
        if xPlayer then
            xPlayer.removeInventoryItem(item, amount)
        end
    end
end

-- =========================================================================
-- EVENTOS DO TRABALHO
-- =========================================================================

--- Evento acionado após passar pela báscula
RegisterNetEvent('fetchq-fruitjob:server:GiveDocument', function(docType)
    local src = source
    
    -- Validação de segurança: apenas aceitar os documentos configurados
    if docType ~= Config.Documents.green and docType ~= Config.Documents.red then
        print(string.format("[FetchQ-FruitJob] Tentativa de manipulação bloqueada. ID: %s tentou receber %s", src, tostring(docType)))
        return 
    end
    
    AddItem(src, docType, 1)
end)

--- Evento acionado após concluir todos os pontos de entrega
RegisterNetEvent('fetchq-fruitjob:server:FinishJob', function(docType)
    local src = source
    local amount = 0
    
    -- Calcular o pagamento e remover o respetivo documento com base na escolha
    if docType == Config.Documents.green then
        amount = math.random(Config.Payment.safe.min, Config.Payment.safe.max)
        RemoveItem(src, Config.Documents.green, 1)
        
    elseif docType == Config.Documents.red then
        amount = math.random(Config.Payment.risky.min, Config.Payment.risky.max)
        RemoveItem(src, Config.Documents.red, 1)
        
    else
        -- Segurança contra exploits de eventos NUI/NetEvents
        print(string.format("[FetchQ-FruitJob] Tentativa de pagamento ilegal bloqueada. ID: %s", src))
        return 
    end
    
    -- Processar o pagamento final
    AddMoney(src, amount, Config.Payment.account)
    
    -- Notificar o jogador sobre os ganhos recorrendo à framework ox_lib
    local paymentMsg = string.format(Config.Notifications.paymentReceived, tostring(amount))
    
    TriggerClientEvent('ox_lib:notify', src, {
        title = 'Transporte de Fruta',
        description = paymentMsg,
        type = 'success',
        position = 'top-right'
    })
end)