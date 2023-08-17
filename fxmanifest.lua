fx_version 'cerulean'
game 'gta5'

description 'ls-weapons'
version '1.0.0'

shared_scripts {
    '@ls-inventory/configs/config.lua',
    '@ls-inventory/configs/config_items.lua',
    'config.lua',
}

server_script 'server/main.lua'
client_script 'client/main.lua'

ui_page { 'web/ui.html' }

files {
    'weaponsnspistol.meta',
    'web/main.css',
    'web/main.js',
    'web/ui.html',
    'web/sounds/*.wav'
}

data_file 'WEAPONINFO_FILE_PATCH' 'weaponsnspistol.meta'

lua54 'yes'
