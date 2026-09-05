roles = [
  { name: "owner", color: "#F5B202" },         # Владелец
  { name: "administrator", color: "#ED1818" }, # Администратор
  { name: "developer", color: "#DA2F8A" },     # Губернатор (по аналогии - элитная роль)
  { name: "moderator", color: "#2727D3" },     # ЭСБР (силовой контроль)
  { name: "helper", color: "#03C487" },        # Судья (помощник, разбор конфликтов)
  { name: "police", color: "#01B4F5" },        # Полиция (контроль, правопорядок)
  { name: "default", color: "#989898" },       # Гражданин (обычный пользователь)
  { name: "duke", color: "#C38CD5" },          # Герцог (благородная элита)
  { name: "elite", color: "#FF8C00" },         # Элита (выделяющийся статус)
  { name: "emperor", color: "#FFD700" },       # Император (высший титул)
  { name: "king", color: "#8B0000" },          # Король (лидер)
  { name: "knight", color: "#4682B4" },        # Рыцарь (заслуженный статус)
  { name: "legenda", color: "#7B68EE" },       # Легенда (особая значимость)
  { name: "lord", color: "#8A2BE2" },          # Лорд (статусная роль)
  { name: "luxs", color: "#E6E6FA" },          # Люкс (дорогая премиум-роль)
  { name: "afk", color: "#555555" }            # AFK (нейтральная роль)
]

roles.each do |role|
  LuckpermsGroup.find_or_create_by(role)
end

permissions = [
  { uuid: "c05c7b32-fa8e-38ce-969a-05a373ed799f", permission: "group.admin", value: true, server: "global", world: "global", expiry: 0, contexts: "" },
  { uuid: "f191c1a8-9ab7-357a-aa02-3272846f93fc", permission: "group.vip", value: true, server: "global", world: "global", expiry: 0, contexts: "" },
  { uuid: "dc70e266-2842-3fd5-9e28-3c4e7ac16a11", permission: "group.default", value: true, server: "global", world: "global", expiry: 0, contexts: "" },
  { uuid: "6d9d4fcb-c973-346d-acce-4d8dbd282e11", permission: "group.helper", value: true, server: "global", world: "global", expiry: 0, contexts: "" },
  { uuid: "6d07d92b-4efa-3e45-9c7d-9c6cfc23342a", permission: "group.builder", value: true, server: "global", world: "global", expiry: 0, contexts: "" },
  { uuid: "de383fd8-f80a-3f8f-9450-20f21e363376", permission: "group.developer", value: true, server: "global", world: "global", expiry: 0, contexts: "" },
  { uuid: "c05c7b32-fa8e-38ce-969a-05a373ed799f", permission: "group.owner", value: true, server: "global", world: "global", expiry: 0, contexts: "" },
  { uuid: "dc70e266-2842-3fd5-9e28-3c4e7ac16a11", permission: "groupbuy.001.vip", value: true, server: "global", world: "global", expiry: 0, contexts: "" },
  { uuid: "dc70e266-2842-3fd5-9e28-3c4e7ac16a11", permission: "groupbuy.002.legend", value: true, server: "global", world: "global", expiry: 0, contexts: "" },
  { uuid: "dc70e266-2842-3fd5-9e28-3c4e7ac16a11", permission: "groupbuy.003.elite", value: true, server: "global", world: "global", expiry: 0, contexts: "" },
  { uuid: "c05c7b32-fa8e-38ce-969a-05a373ed799f", permission: "group.afk", value: true, server: "global", world: "global", expiry: 0, contexts: "" },
  { uuid: "dc70e266-2842-3fd5-9e28-3c4e7ac16a11", permission: "group.sponsor", value: true, server: "global", world: "global", expiry: 0, contexts: "" },
  { uuid: "dc70e266-2842-3fd5-9e28-3c4e7ac16a11", permission: "groupbuy.004.royal", value: true, server: "global", world: "global", expiry: 0, contexts: "" },
  { uuid: "dc70e266-2842-3fd5-9e28-3c4e7ac16a11", permission: "groupbuy.005.elite", value: true, server: "global", world: "global", expiry: 0, contexts: "" },
  { uuid: "dc70e266-2842-3fd5-9e28-3c4e7ac16a11", permission: "groupbuy.007.duke", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { uuid: "dc70e266-2842-3fd5-9e28-3c4e7ac16a11", permission: "groupbuy.009.king", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { uuid: "dc70e266-2842-3fd5-9e28-3c4e7ac16a11", permission: "groupbuy.010.emperor", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { uuid: "dc70e266-2842-3fd5-9e28-3c4e7ac16a11", permission: "prefix.cmds", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { uuid: "dc70e266-2842-3fd5-9e28-3c4e7ac16a11", permission: "meta.lp-editor-key.9kUKTImW8wTihe/AU6SVSBBnwcw=", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { uuid: "dc70e266-2842-3fd5-9e28-3c4e7ac16a11", permission: "groupbuy.002.luxs", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { uuid: "dc70e266-2842-3fd5-9e28-3c4e7ac16a11", permission: "groupbuy.008.lord", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { uuid: "dc70e266-2842-3fd5-9e28-3c4e7ac16a11", permission: "suffix.20.§r | §e[§8§lЭСБР§e]§r", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { uuid: "dc70e266-2842-3fd5-9e28-3c4e7ac16a11", permission: "groupbuy.006.knight", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { uuid: "dc70e266-2842-3fd5-9e28-3c4e7ac16a11", permission: "groupbuy.003.legenda", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { uuid: "de838fd3-f80a-3f8f-9450-20f21e363376", permission: "group.default", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { uuid: "de838fd3-f80a-3f8f-9450-20f21e363376", permission: "group.elite", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { uuid: "de838fd3-f80a-3f8f-9450-20f21e363376", permission: "groupbuy.005.elite", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { uuid: "cf31d5e1-7a0a-3ae5-a249-3bb35cd631b6", permission: "group.default", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { uuid: "cf31d5e1-7a0a-3ae5-a249-3bb35cd631b6", permission: "groupbuy.002.luxs", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { uuid: "cf31d5e1-7a0a-3ae5-a249-3bb35cd631b6", permission: "groupbuy.001.vip", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { uuid: "c05c7b32-fa8e-38ce-969a-05a373ed799f", permission: "grouphave.012.twitch", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { uuid: "c05c7b32-fa8e-38ce-969a-05a373ed799f", permission: "grouphave.011.tiktok", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { uuid: "c05c7b32-fa8e-38ce-969a-05a373ed799f", permission: "grouphave.013.youtube", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { uuid: "6d0792b2-4efa-3e45-9c7d-949cf6f32342", permission: "group.default", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { uuid: "6d0792b2-4efa-3e45-9c7d-949cf6f32342", permission: "suffix.20.§r | Босин§r", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { uuid: "6d0792b2-4efa-3e45-9c7d-949cf6f32342", permission: "suffix.cmds", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { uuid: "f191ca18-9ab7-357a-aa02-3272846f93fc", permission: "group.default", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { uuid: "f191ca18-9ab7-357a-aa02-3272846f93fc", permission: "suffix.20.§r | §e[§8ЭСБР§e]§r", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" }
]

permissions.each do |permission|
  LuckpermsUserPermission.find_or_create_by(permission)
end

group_permissions = [
  { name: "tiktok", permission: "weight.11", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "tiktok", permission: "displayname.ТикТок", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "tiktok", permission: "prefix.11.#25F4EE[Tik#FE2C55Tok] #FFFAFA▷ &r", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "moderator", permission: "weight.17", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "moderator", permission: "displayname.Модератор", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "moderator", permission: "group.helper", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "moderator", permission: "prefix.17.&e[#1E90FFМодератор&e] &e▷ &r", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "administrator", permission: "displayname.Администратор", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "administrator", permission: "prefix.18.&e[#DC143CАдминистратор&e] &e▷ &r", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "administrator", permission: "group.moderator", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "administrator", permission: "weight.18", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "elite", permission: "displayname.Элита", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "elite", permission: "group.royal", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "elite", permission: "prefix.5.#FF4500[&eElite#FF4500] #FF4500▷ &r", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "elite", permission: "weight.5", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "twitch", permission: "prefix.12.#9146FF[#E0FFFFStreamer#9146FF] #9146FF▷...", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "twitch", permission: "weight.12", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "twitch", permission: "displayname.Твич", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "youtube", permission: "prefix.13.#FFFAFA[#FFFAFAYou#E81C0ETube#FFFAFA] #E...", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "youtube", permission: "displayname.Ютубер", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "youtube", permission: "weight.13", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "king", permission: "weight.9", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "king", permission: "displayname.Король", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "king", permission: "group.lord", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "king", permission: "prefix.9.#F0E68C[#DAA520Король#F0E68C] #F0E68C▷ &r", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "lord", permission: "displayname.Лорд", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "lord", permission: "group.duke", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "lord", permission: "weight.8", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "lord", permission: "prefix.8.#C0C0C0[#7B68EEЛорд#C0C0C0] #C0C0C0▷ &r", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "helper", permission: "displayname.Хелпер", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "helper", permission: "group.default", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "helper", permission: "prefix.16.&e[#32CD32Хелпер&e] &e▷ &r", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "helper", permission: "weight.16", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "sponsor", permission: "weight.14", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "sponsor", permission: "prefix.14.#DAA520[#FEFE22Спонсор#DAA520] ▷ &r", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "sponsor", permission: "displayname.Спонсор", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "royal", permission: "group.legenda", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "royal", permission: "prefix.4.#00BFFF[#FF1493Royal#00BFFF] #00BFFF▷ &r", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "royal", permission: "weight.4", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "royal", permission: "displayname.Роял", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "emperor", permission: "displayname.Император", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "emperor", permission: "group.king", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "emperor", permission: "prefix.10.#00FF7F[#FF4500Император#00FF7F] #00FF7F...", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "emperor", permission: "weight.10", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "legenda", permission: "prefix.3.&f[&eLegenda&f] &f▷ &r", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "legenda", permission: "weight.3", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "legenda", permission: "displayname.Легенда", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "legenda", permission: "group.luxs", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "developer", permission: "weight.30", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "developer", permission: "prefix.30.&e[#FF0000Разработчик&e] &e▷ &r", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "developer", permission: "displayname.Разработчик", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "duke", permission: "prefix.7.&f[#BA55D3Герцог&f] &f▷ &r", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "duke", permission: "weight.7", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "duke", permission: "group.knight", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "duke", permission: "displayname.Герцог", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "vip", permission: "prefix.1.&f[&6ViP&f] &f▷ &r", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "vip", permission: "group.default", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "vip", permission: "weight.1", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "vip", permission: "displayname.ВИП", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "luxs", permission: "weight.2", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "luxs", permission: "group.vip", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "luxs", permission: "displayname.Люкс", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "luxs", permission: "prefix.2.&f[&3Luxs&f] &f▷ &r", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "knight", permission: "weight.6", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "knight", permission: "group.default", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "knight", permission: "displayname.Рыцарь", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "knight", permission: "prefix.6.&f[#00CED1Рыцарь&f] &f▷ &r", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "default", permission: "mycommand.cmd.b_command_help", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "default", permission: "mycommand.cmd.rep_command_help", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "default", permission: "mycommand.cmd.do_command_rp", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "default", permission: "sr.lore", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "default", permission: "mycommand.cmd.roll_command_help", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "default", permission: "mycommand.cmd.goida_command_help", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "default", permission: "sr.name", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "default", permission: "essentials.hat", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "default", permission: "mycommand.cmd.suffix.cmds", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "default", permission: "mycommand.cmd.title_command_help", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "default", permission: "mycommand.cmd.Help_text_command", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "default", permission: "mycommand.cmd.try_command_help", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "default", permission: "minecraft.command.tellraw", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "default", permission: "mycommand.cmd.goida_rp", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "default", permission: "mycommand.cmd.setname_command_help", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "default", permission: "mycommand.cmd.me_command_help", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "default", permission: "displayname.Игрок", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "default", permission: "tab.scoreboard.toggle", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "default", permission: "weight.0", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "default", permission: "mycommand.cmd.me_command_rp", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "default", permission: "minecraft.command.minecraft:tellraw", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "default", permission: "mycommand.cmd.Reputation_System_Disrespect", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "default", permission: "mycommand.cmd.try_command_rp", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "default", permission: "sr.removelore", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "default", permission: "mycommand.cmd.Reputation_System_Respect", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "default", permission: "mycommand.cmd.disrep_command_help", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "default", permission: "sr.color", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "default", permission: "mycommand.cmd.do_command_help", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "default", permission: "mycommand.cmd.setlore_command_help", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "default", permission: "mycommand.cmd.title_command", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "default", permission: "mycommand.cmd.b_command_rp", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "default", permission: "prefix.0.#C0C0C0[&fИгрок#C0C0C0] &f▷ &r", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "default", permission: "mycommand.cmd.roll_command_rp", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "default", permission: "deluxemenus.marbank_use", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "owner", permission: "displayname.Владелец", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "owner", permission: "weight.999", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "owner", permission: "prefix.999.#FF4500[#FFE259Владелец#FF4500] ▷ &r", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "default", permission: "deluxemenus.prefixmenu", value: false, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "default", permission: "mycommand.cmd.msgpl-sender", value: false, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "default", permission: "mycommand.cmd.hat_command_help", value: true, server: "global", world: "global", expiry: 0, contexts: "{}" },
  { name: "default", permission: "mycommand.cmd.msg_command_help", value: false, server: "global", world: "global", expiry: 0, contexts: "{}" }
]

group_permissions.each do |permission|
  LuckpermsGroupPermission.find_or_create_by(permission)
end

authme_records = [
  {
    username: "adminski",
    realname: "Adminski",
    password: "$SHA$5d8d597b7d7d55ec$5a0b8b10a2d390fcb3c0d4560d0a8e4d3f678a5d",
    ip: "37.214.57.22",
    lastlogin: Time.at(1747699268.807),
    x: -97.85068864238987,
    y: 96.5,
    z: 488.9136710114753,
    world: "world",
    regdate: Time.at(1747591153.829),
    regip: "37.214.57.22",
    yaw: 144.535,
    pitch: -8.26089,
    isLogged: false,
    hasSession: true
  },
  {
    username: "realtap0k",
    realname: "RealTaP0K",
    password: "$SHA$5d8d597b7d7d55ec$c4a4d1d3a6f5e3d2c1b0a9d8e7f6a5b4",
    ip: "37.214.57.22",
    lastlogin: Time.at(1747593769.109),
    x: -82.02840430866499,
    y: 77.0,
    z: 509.20573437346286,
    world: "world",
    regdate: Time.at(1747593731.644),
    regip: "37.214.57.22",
    yaw: -131.36,
    pitch: 28.0564,
    isLogged: false,
    hasSession: true
  },
  {
    username: "goldie228",
    realname: "Goldie228",
    password: "$SHA$5d8d597b7d7d55ec$9e8f7d6c5b4a3d2c1b0a9d8e7f6a5b4",
    ip: "46.216.21.98",
    lastlogin: Time.at(1747854509.229),
    x: 879.1134034832833,
    y: 78.0,
    z: 680.427332473291,
    world: "world",
    regdate: Time.at(1747701130.954),
    regip: "46.216.22.176",
    yaw: -131.346,
    pitch: 32.4055,
    isLogged: false,
    hasSession: true
  }
]

authme_records.each do |record|
  Authme.find_or_create_by(username: record[:username]) do |a|
    a.assign_attributes(record)
  end
end

luckperms_players = [
  {
    uuid: "6d0792b2-4efa-3e45-9c7d-949cf6f32342",
    username: "fanera1",
    primary_group: "default"
  },
  {
    uuid: "c05c7b32-fa8e-38ce-969a-05a373ed799f",
    username: "adminski",
    primary_group: "default"
  },
  {
    uuid: "cf31d5e1-7a0a-3ae5-a249-3bb35cd631b6",
    username: "kot33325",
    primary_group: "default"
  },
  {
    uuid: "dc70e266-2842-3fd5-9e28-3c4e7ac16a11",
    username: "realtap0k",
    primary_group: "default"
  },
  {
    uuid: "de838fd3-f80a-3f8f-9450-20f21e363376",
    username: "goldie228",
    primary_group: "default"
  },
  {
    uuid: "f191ca18-9ab7-357a-aa02-3272846f93fc",
    username: "fitzowski",
    primary_group: "default"
  }
]

luckperms_players.each do |player|
  LuckpermsPlayer.find_or_create_by(uuid: player[:uuid]) do |lp|
    lp.username = player[:username]
    lp.primary_group = player[:primary_group]
  end
end
