##
## Grenadine Test
##

assert("Grenadine#hello") do
  t = Grenadine.new "hello"
  assert_equal("hello", t.hello)
end

assert("Grenadine#bye") do
  t = Grenadine.new "hello"
  assert_equal("hello bye", t.bye)
end

assert("Grenadine.hi") do
  assert_equal("hi!!", Grenadine.hi)
end
