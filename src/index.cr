require "ohm"

Ohm.redis.call "SET", "Foo", "Bar"
res = Ohm.redis.call "GET", "Foo"
puts "Get Foo #{res}"
