# grenadine   [![Build Status](https://travis-ci.org/udzura/grenadine.svg?branch=master)](https://travis-ci.org/udzura/grenadine)
Grenadine class
## install by mrbgems
- add conf.gem line to `build_config.rb`

```ruby
MRuby::Build.new do |conf|

    # ... (snip) ...

    conf.gem :github => 'udzura/grenadine'
end
```
## example
```ruby
p Grenadine.hi
#=> "hi!!"
t = Grenadine.new "hello"
p t.hello
#=> "hello"
p t.bye
#=> "hello bye"
```

## License
under the MIT License:
- see LICENSE file
