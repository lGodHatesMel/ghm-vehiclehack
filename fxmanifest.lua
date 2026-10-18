fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'ghm-vehiclehack'
author 'GodHatesMe'
version '2.0.0'
description 'Vehicle Hacker: remote vehicle sabotage, control and chaos for sd-phone (or a standalone screen)'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'bridge/shared.lua',
}

client_scripts {
    'bridge/client.lua',
    'bridge/fuel.lua',
    'client/utils.lua',
    'client/effects.lua',
    'client/main.lua',
}

server_scripts {
    'bridge/server.lua',
    'bridge/inventory.lua',
    'server/main.lua',
}

ui_page 'ui/dist/index.html'
-- ui_page 'http://localhost:5173' -- swap in while working on the UI with `npm run dev`

files {
    'locales/*.json',
    'ui/dist/**/*',
}

-- ox_lib reads the locale files from locales/ and follows its own `ox:locale` convar.
ox_lib 'locale'

-- sd-phone is optional (Config.UseSdPhone = false runs standalone), so it is not listed here.
-- The inventory is optional too: bridge/inventory.lua finds it (see Config.Inventory).
-- Exactly one of qbx_core / qb-core / es_extended is expected; bridge/shared.lua finds out which.
dependencies {
    'ox_lib',
}
