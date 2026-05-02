Config = {}

Config.Debug = false
Config.JobCheckInterval = 2000
Config.JobCheckIntervalNear = 500
Config.NearDistance = 50.0
Config.MaxDistanceFromTruck = 200.0
Config.MinGroupSize = 2
Config.MaxGroupSize = 4

Config.DepotNPC = {
    model = 's_m_m_warehouse_01',
    coords = vector4(1218.35, -3226.74, 4.88, 354.06),
    blip = {
        sprite = 478,
        color = 2,
        scale = 0.85,
        label = 'Fruit Depot'
    },
    interactDistance = 2.5,
}

Config.Farm = {
    coords = vector3(2414.68, 4993.38, 46.22),
    radius = 30.0,
    blip = {
        sprite = 469,
        color = 2,
        scale = 0.9,
        label = 'Fruit Farm'
    },
    arrivalDistance = 50.0,
    loadingBays = {
        {
            label = 'Bay 1',
            parkCoord = vector4(2412.55, 4990.05, 46.46, 308.0),
            markerCoord = vector3(2412.55, 4990.05, 45.46),
        },
        {
            label = 'Bay 2',
            parkCoord = vector4(2398.55, 4990.05, 46.46, 308.0),
            markerCoord = vector3(2398.55, 4990.05, 45.46),
        },
        {
            label = 'Bay 3',
            parkCoord = vector4(2384.55, 4990.05, 46.46, 308.0),
            markerCoord = vector3(2384.55, 4990.05, 45.46),
        },
        {
            label = 'Bay 4',
            parkCoord = vector4(2370.55, 4990.05, 46.46, 308.0),
            markerCoord = vector3(2370.55, 4990.05, 45.46),
        },
    },
    bayMarkerRadius = 4.0,
    bayInteractDistance = 6.0,
}

Config.Truck = {
    model = 'mule3',
    spawnCoords = {
        vector4(1202.97, -3229.71, 6.18, 269.34),
        vector4(1202.97, -3235.71, 6.18, 269.34),
        vector4(1202.97, -3241.71, 6.18, 269.34),
        vector4(1202.97, -3247.71, 6.18, 269.34),
    },
    spawnCoord = vector4(1202.97, -3229.71, 6.18, 269.34),
    loadMarkerOffset = vector3(0.0, -4.5, 0.0),
    loadMarkerRadius = 2.5,
    loadMarkerColor = {r = 50, g = 200, b = 50, a = 150},
}

Config.SoloMode = {
    npcModel = 'a_m_m_farmer_01',
    npcCount = 3,
    npcPickupOffsets = {
        vector3(-3.0, 3.0, 0.0),
        vector3(0.0, 4.0, 0.0),
        vector3(3.0, 3.0, 0.0),
    },
    truckDropoffOffset = vector3(0.0, -5.0, 0.0),
    loadRounds = 2,
    loadRoundsMax = 3,
    walkSpeed = 1.0,
    timePerRound = 15000,
    crateProp = 'prop_veg_crop_03_cab',
    crateCarryAnimDict = 'anim@heists@box_carry@',
    crateCarryAnimName = 'idle',
    crateOnTruckOffsets = {
        vector3(-0.5, -2.5, 0.05),
        vector3(0.5, -2.5, 0.05),
        vector3(-0.5, -1.5, 0.05),
        vector3(0.5, -1.5, 0.05),
        vector3(-0.5, -0.5, 0.05),
        vector3(0.5, -0.5, 0.05),
        vector3(-0.5, -2.5, 0.55),
        vector3(0.5, -2.5, 0.55),
        vector3(0.0, -2.0, 0.05),
    },
}

Config.GroupMode = {
    crateProp = 'prop_veg_crop_03_cab',
    crateCarryAnimDict = 'anim@heists@box_carry@',
    crateCarryAnimName = 'idle',
    crateAttachBone = 28422,
    crateAttachOffset = vector3(0.0, 0.0, 0.0),
    crateAttachRotation = vector3(0.0, 0.0, 0.0),
    cratePickupDistance = 1.5,
    loadProgressTime = 2000,
    -- Minimum number of crates that must be loaded before the job can proceed
    crateTarget = 6,
    cratePositions = {
        vector3(-8.0, 2.3, 0.36),
        vector3(-6.5, 2.3, 0.36),
        vector3(-8.0, 3.8, 0.36),
        vector3(-6.27, -22.16, -0.16),
        vector3(-4.77, -22.16, -0.16),
        vector3(-6.27, -20.66, -0.16),
    },
}

Config.Scale = {
    coords = vector3(2428.98, 4775.75, 43.58),
    interactDistance = 3.0,
    blip = {
        sprite = 478,
        color = 5,
        scale = 0.8,
        label = 'Weigh Station'
    }
}

Config.DeliveryPoints = {
    count = 3,
    countMax = 4,
    deliveryProgressTime = 8000,
    interactDistance = 15.0,
    locations = {
        {
            coords = vector3(25.74, -1347.29, 29.50),
            label = 'Market - Strawberry',
            npcSpawn = vector4(24.49, -1345.08, 29.50, 270.0),
            truckPark = vector3(28.0, -1340.0, 29.50),
        },
        {
            coords = vector3(-47.02, -1757.64, 29.42),
            label = 'Market - Davis',
            npcSpawn = vector4(-46.45, -1756.0, 29.42, 50.0),
            truckPark = vector3(-43.0, -1760.0, 29.42),
        },
        {
            coords = vector3(1160.42, -323.28, 69.21),
            label = 'Market - Mirror Park',
            npcSpawn = vector4(1159.46, -321.49, 69.21, 100.0),
            truckPark = vector3(1163.0, -326.0, 69.21),
        },
        {
            coords = vector3(-706.15, -913.98, 19.22),
            label = 'Market - Little Seoul',
            npcSpawn = vector4(-705.63, -912.34, 19.22, 180.0),
            truckPark = vector3(-709.0, -917.0, 19.22),
        },
        {
            coords = vector3(373.53, 325.62, 103.57),
            label = 'Market - Downtown Vinewood',
            npcSpawn = vector4(373.00, 327.10, 103.57, 250.0),
            truckPark = vector3(377.0, 322.0, 103.57),
        },
        {
            coords = vector3(2557.46, 382.12, 108.62),
            label = 'Market - Tataviam Mountains',
            npcSpawn = vector4(2556.90, 383.50, 108.62, 0.0),
            truckPark = vector3(2560.0, 379.0, 108.62),
        },
        {
            coords = vector3(1729.22, 6414.13, 35.04),
            label = 'Market - Paleto Bay',
            npcSpawn = vector4(1728.50, 6415.80, 35.04, 240.0),
            truckPark = vector3(1732.0, 6411.0, 35.04),
        },
        {
            coords = vector3(1961.49, 3740.71, 32.34),
            label = 'Market - Sandy Shores',
            npcSpawn = vector4(1960.80, 3742.20, 32.34, 300.0),
            truckPark = vector3(1964.0, 3738.0, 32.34),
        },
    },
    blip = {
        sprite = 478,
        color = 1,
        scale = 0.75,
        label = 'Delivery Point'
    }
}

Config.DeliveryNPC = {
    model = 's_m_m_strvend_01',
    walkSpeed = 1.0,
    crateCarryAnimDict = 'anim@heists@box_carry@',
    crateCarryAnimName = 'idle',
    crateProp = 'prop_veg_crop_03_cab',
    truckApproachDist = 2.5,
    maxWaitTime = 20000,
}

Config.Payment = {
    safe = {
        min = 3500,
        max = 5000,
    },
    risky = {
        min = 7000,
        max = 12000,
    },
    account = 'cash',
}

Config.Documents = {
    green = 'green_document',
    red = 'red_document',
}

Config.Notifications = {
    jobAccepted = '📋 Fruit Transport job accepted! Head to the farm.',
    jobAlreadyActive = '⚠️ You already have an active job!',
    arrivedAtFarm = '🌾 You arrived at the farm!',
    soloChoice = '🤔 Choose transport method',
    groupCrateInfo = '📦 Load the crates on the ground onto the truck! (E key)',
    npcLoading = '⏳ Workers are loading crates...',
    npcLoadComplete = '✅ Crates loaded! Head to the delivery points.',
    cratePickedUp = '📦 You picked up a crate! Bring it to the truck.',
    crateLoaded = '✅ Crate loaded! (%d/%d)',
    allCratesLoaded = '✅ All crates loaded! Head to the weigh station.',
    alreadyCarrying = '⚠️ You are already carrying a crate!',
    noCrateInHand = '⚠️ You have no crate in hand!',
    arrivedAtScale = '⚖️ You arrived at the weigh station! Press E to weigh.',
    scaleChoice = '⚖️ Choose document type',
    documentReceived = '📄 Document received! Check your inventory.',
    deliveryStart = '🚚 Head to delivery points! (%d points)',
    deliveryProgress = '📦 Delivering...',
    deliveryComplete = '✅ Delivery complete! (%d/%d)',
    allDeliveriesComplete = '🎉 All deliveries completed!',
    paymentReceived = '💰 Payment received: $%s',
    jobCancelled = '❌ Job cancelled!',
    truckDestroyed = '💥 Truck was damaged! Job cancelled.',
    tooFarFromTruck = '📏 You went too far from the truck! Job cancelled.',
    truckNotSpawned = '⚠️ Could not spawn truck!',
    policeCheckGreen = '✅ Legal document - No issues.',
    policeCheckRed = '🚨 Smuggling document detected!',
    pressE = '[E] %s',
    pressEPickup = '[E] Pick Up Crate',
    pressELoad = '[E] Load Crate',
    pressEDeliver = '[E] Deliver',
    pressEScale = '[E] Use Weigh Station',
    pressEStartJob = '[E] Start Fruit Transport Job',
}

Config.MenuTexts = {
    riskTitle = 'Transport Method Selection',
    safeOption = '🟢 Risk-Free (Legal Document)',
    safeDescription = 'Lower earnings, no issues at police checkpoints.',
    riskyOption = '🔴 Risky (Smuggling Document)',
    riskyDescription = 'Higher earnings, but risk of getting caught at police checkpoints!',
}