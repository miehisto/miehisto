/*
** mrb_grenadine.c - Grenadine class
**
** Copyright (c) Uchio Kondo 2019
**
** See Copyright Notice in LICENSE
*/

#include "mruby.h"
#include "mruby/data.h"
#include "mrb_grenadine.h"

#define DONE mrb_gc_arena_restore(mrb, 0);

void mrb_grenadine_gem_init(mrb_state *mrb)
{
  mrb_define_module(mrb, "Grenadine");
  DONE;
}

void mrb_grenadine_gem_final(mrb_state *mrb)
{
}
