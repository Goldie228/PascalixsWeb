Role.find_or_create_by!(name: "User", color: "#A0A0A0")
Role.find_or_create_by!(name: "Player", color: "#EDEDED")
Role.find_or_create_by!(name: "DEV", color: "#EF4444")
Role.find_or_create_by!(name: "OWNER", color: "#F59E0B")

reasons = [
  # BAN — тяжёлые игровые нарушения
  { rule_number: 21,  punishment_type: :ban,  description: "Использование читов",                             price: "5.00" },
  { rule_number: 22,  punishment_type: :ban,  description: "Дюп предметов и ресурсов",                        price: "5.00" },
  { rule_number: 231, punishment_type: :ban,  description: "Гриферство: порча построек",                      price: "5.00" },
  { rule_number: 232, punishment_type: :ban,  description: "Гриферство: кража/уничтожение ресурсов",          price: "4.50" },
  { rule_number: 233, punishment_type: :ban,  description: "Гриферство: помехи другим игрокам",               price: "4.50" },
  { rule_number: 234, punishment_type: :ban,  description: "Гриферство: баги/софт во вред",                   price: "5.00" },
  { rule_number: 235, punishment_type: :ban,  description: "Гриферство: саботаж игрового процесса",           price: "4.50" },
  { rule_number: 24,  punishment_type: :ban,  description: "Создание лавакастов",                             price: "4.00" },
  { rule_number: 25,  punishment_type: :ban,  description: "Постройка лаг-машин",                             price: "5.00" },
  { rule_number: 261, punishment_type: :ban,  description: "Передача аккаунта третьим лицам",                price: "4.50" },
  { rule_number: 262, punishment_type: :ban,  description: "Создание условий доступа третьим лицам",         price: "4.50" },
  { rule_number: 263, punishment_type: :ban,  description: "Продажа / обмен аккаунта",                        price: "4.50" },
  { rule_number: 264, punishment_type: :ban,  description: "Доступ к чужим аккаунтам",                        price: "5.00" },
  { rule_number: 265, punishment_type: :ban,  description: "Махинации с аккаунтами сервера",                  price: "5.00" },
  { rule_number: 27,  punishment_type: :ban,  description: "Препятствие работе администрации",                price: "3.50" },
  { rule_number: 28,  punishment_type: :ban,  description: "Использование чужих ников",                       price: "4.00" },
  { rule_number: 29,  punishment_type: :ban,  description: "Выдача себя за администрацию",                    price: "3.00" },
  { rule_number: 210, punishment_type: :ban,  description: "Реклама сторонних проектов",                      price: "3.50" },

  # MUTE — нарушения чата и коммуникации
  { rule_number: 301, punishment_type: :mute, description: "Оскорбления игроков",                             price: "3.00" },
  { rule_number: 302, punishment_type: :mute, description: "Спам в чат",                                      price: "2.00" },
  { rule_number: 303, punishment_type: :mute, description: "Капс/флуд",                                       price: "1.50" },
  { rule_number: 304, punishment_type: :mute, description: "Нецензурная лексика",                             price: "2.50" },
  { rule_number: 305, punishment_type: :mute, description: "Провокации и токсичность",                        price: "3.50" },
  { rule_number: 306, punishment_type: :mute, description: "Навязчивая реклама (в чат)",                      price: "3.00" },
  { rule_number: 307, punishment_type: :mute, description: "Материал 18+ или NSFW в чатах",                   price: "4.00" },
  { rule_number: 308, punishment_type: :mute, description: "Подстрекательство к нарушению правил",            price: "4.50" }
]

reasons.each do |attrs|
  PunishmentReason.find_or_create_by!(rule_number: attrs[:rule_number], punishment_type: attrs[:punishment_type]) do |reason|
    reason.description = attrs[:description]
    reason.price = attrs[:price]
  end
end

# Создание продуктов с ценами
Product.find_or_create_by!(product_type: "pass_purchase") do |product|
  product.price = 3.00
end

Product.find_or_create_by!(product_type: "pass_gift") do |product|
  product.price = 3.00
end

Product.find_or_create_by!(product_type: "sponsor") do |product|
  product.price = 10.00
end
