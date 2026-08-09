FactoryBot.define do
  factory :authme do
    sequence(:username) { |n| "player_#{n}" }
    sequence(:realname) { |n| "Player_#{n}" }
    password { "$2a$10$abcdefghijklmnopqrstuuABCDEFGHIJKLMNOPQRSTUVWXYZ01234" }
    ip { "192.168.1.100" }
    lastlogin { Time.current.to_i }
    x { 100.5 }
    y { 64.0 }
    z { -200.3 }
    world { "world" }
    regdate { Time.current.to_i }
    regip { "192.168.1.1" }
    yaw { 0.0 }
    pitch { 0.0 }
    email { "player@example.com" }
    isLogged { 0 }
    hasSession { 0 }
    totp { nil }
  end
end
