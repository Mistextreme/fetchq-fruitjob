fx_version 'cerulean'
game 'gta5'
lua54 'yes'


description 'Fruit Transport Job System - Solo & Group support, document system, delivery points'
version '1.0.0'

escrow_ignore {
    'config.lua',
    'html/index.html',
    'html/style.css',
    'html/script.js',
}
shared_scripts {
    '@ox_lib/init.lua',
    '@qb-core/shared/locale.lua',
    'config.lua'
}

client_scripts {
    'client/utils.lua',
    'client/main.lua'
}

server_script 'server/main.lua'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js'
}

dependency '/assetpacks'
dependency '/assetpacks'