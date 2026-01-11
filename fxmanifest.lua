fx_version 'cerulean'
game 'gta5'

author 'Wess'
description 'Sistema Completo de Mecánico'
version '1.0.0'

lua54 'yes'

shared_scripts {
    'config.lua',
    'locales/es.lua',
    'bridge/**.lua'
}

client_scripts {
    'client/utils.lua',
    'client/mechanic/admin.lua',
    'client/mechanic/editor.lua',
    'client/mechanic/zones.lua',
    'client/tablet/tablet.lua',
    'client/tablet/ui.lua',
    'client/tablet/hud.lua',
    'client/tablet/apps/**.lua',
    'client/main.lua'
}

server_scripts {
    'server/database.lua',
    'server/business.lua',
    'server/invoices.lua',
    'server/members.lua',
    'server/main.lua'
}

ui_page 'html/index.html' -- Asegúrate de que apunte a TU archivo

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/img/*.png' 
}

escrow_ignore {
    'config.lua',
    'locales/*.lua',
    'bridge/*.lua'
}

dependency 'ox_lib'

provide 'qb-mechanic'
provide 'esx_mechanicjob'