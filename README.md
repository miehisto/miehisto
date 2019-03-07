# Grenadine

A checkpoint manager for application servers

## Install

### System requirement

* Kernel 3.11 (CRIU's requirement, newer is better)
* `criu` command and service

### Binary/Package

TODO...

### Build from source

```bash
git clone https://github.com/udzura/grenadine.git; cd grenadine
rake
sudo mv ./mruby/bin/grenadine /usr/local/bin
```

* Both libcriu and libprce will be statically linked.
* Also see [mruby itself's prerequisites](https://github.com/mruby/mruby/blob/master/doc/guides/compile.md#prerequisites)

## Usage

### Create service via grenadine

```console
$ sudo grenadine daemon -e RACK_ENV=production -- \
    /usr/bin/rackup -b \
    'run lambda {|e| [200, {"Content-Type" => "text/plain"}, ["Hello, Grenadine!\n"]] }'
Spawned: 10804
$ curl localhost:9292
Hello, Grenadine!
```

### Then, dump this process

```console
$ sudo grenadine dump
Dumped into: /var/lib/grenadine/images/c59a2e87cf3b0beb52544e14b93b0cf5
```

### You will get some images

```console
$ sudo grenadine list
IDX     IMAGE_ID                                CTIME                           COMM            MEM_SIZE
  0     c59a2e87cf3b0beb52544e14b93b0cf5        Thu Mar 07 09:28:13 2019        rackup          8.68MiB 
  1     e7d5d4c04af3f40eb3851c7037f366fc        Thu Mar 07 08:49:53 2019        rackup          8.75MiB 
  2     d179fd25a7d68889c5d068cf3df1531b        Thu Mar 07 08:48:43 2019        rackup          8.61MiB
```

### You can restore process from these images

```console
$ sudo ./mruby/bin/grenadine restore 0
Restored c59a2e87cf3b0beb52544e14b93b0cf5: 10937
$ curl localhost:9292
Hello, Grenadine!
```

More information/usecases are TBD :(

## License

Under the MIT License. See LICENSE file.
