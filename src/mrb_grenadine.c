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

typedef struct {
  char *str;
  int len;
} mrb_grenadine_data;

static const struct mrb_data_type mrb_grenadine_data_type = {
  "mrb_grenadine_data", mrb_free,
};

static mrb_value mrb_grenadine_init(mrb_state *mrb, mrb_value self)
{
  mrb_grenadine_data *data;
  char *str;
  int len;

  data = (mrb_grenadine_data *)DATA_PTR(self);
  if (data) {
    mrb_free(mrb, data);
  }
  DATA_TYPE(self) = &mrb_grenadine_data_type;
  DATA_PTR(self) = NULL;

  mrb_get_args(mrb, "s", &str, &len);
  data = (mrb_grenadine_data *)mrb_malloc(mrb, sizeof(mrb_grenadine_data));
  data->str = str;
  data->len = len;
  DATA_PTR(self) = data;

  return self;
}

static mrb_value mrb_grenadine_hello(mrb_state *mrb, mrb_value self)
{
  mrb_grenadine_data *data = DATA_PTR(self);

  return mrb_str_new(mrb, data->str, data->len);
}

static mrb_value mrb_grenadine_hi(mrb_state *mrb, mrb_value self)
{
  return mrb_str_new_cstr(mrb, "hi!!");
}

void mrb_grenadine_gem_init(mrb_state *mrb)
{
  struct RClass *grenadine;
  grenadine = mrb_define_class(mrb, "Grenadine", mrb->object_class);
  mrb_define_method(mrb, grenadine, "initialize", mrb_grenadine_init, MRB_ARGS_REQ(1));
  mrb_define_method(mrb, grenadine, "hello", mrb_grenadine_hello, MRB_ARGS_NONE());
  mrb_define_class_method(mrb, grenadine, "hi", mrb_grenadine_hi, MRB_ARGS_NONE());
  DONE;
}

void mrb_grenadine_gem_final(mrb_state *mrb)
{
}

