/*
** mrb_grenadine.c - Grenadine class
**
** Copyright (c) Uchio Kondo 2019
**
** See Copyright Notice in LICENSE
*/

#define _GNU_SOURCE
#include <stdio.h>
#include <unistd.h>
#include <sys/syscall.h>
#include <sys/mount.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <syslog.h>
#include <string.h>
#include <errno.h>
#include <time.h>

#include <mruby.h>
#include <mruby/string.h>
#include <mruby/hash.h>
#include <mruby/error.h>

#include "miehisto.h"

#define DONE mrb_gc_arena_restore(mrb, 0);

static int pivot_root(const char *new_root, const char *put_old){
  return (int)syscall(SYS_pivot_root, new_root, put_old);
}

/* This function is written after lxc/conf.c
   https://github.com/lxc/lxc/blob/3695b24384b71662a1225f6cc25f702667fbbe38/src/lxc/conf.c#L1495 */
static int gren_pivot_root(mrb_state *mrb, const char *rootfs)
{
  int oldroot;
  int newroot = -1, ret = -1;

  oldroot = open("/", O_DIRECTORY | O_RDONLY | O_CLOEXEC);
  if (oldroot < 0) {
    mrb_sys_fail(mrb, "Failed to open old root directory");
    return -1;
  }

  newroot = open(rootfs, O_DIRECTORY | O_RDONLY | O_CLOEXEC);
  if (newroot < 0) {
    mrb_sys_fail(mrb, "Failed to open new root directory");
    goto on_error;
  }

  /* change into new root fs */
  ret = fchdir(newroot);
  if (ret < 0) {
    ret = -1;
    mrb_sys_fail(mrb, "Failed to change to new rootfs");
    goto on_error;
  }

  /* pivot_root into our new root fs */
  ret = pivot_root(".", ".");
  if (ret < 0) {
    ret = -1;
    mrb_sys_fail(mrb, "Failed to pivot_root()");
    goto on_error;
  }

  /* At this point the old-root is mounted on top of our new-root. To
   * unmounted it we must not be chdir'd into it, so escape back to
   * old-root.
   */
  ret = fchdir(oldroot);
  if (ret < 0) {
    ret = -1;
    mrb_sys_fail(mrb, "Failed to enter old root directory");
    goto on_error;
  }

  /* Make oldroot rslave to make sure our umounts don't propagate to the
   * host.
   */
  ret = mount("", ".", "", MS_SLAVE | MS_REC, NULL);
  if (ret < 0) {
    ret = -1;
    mrb_sys_fail(mrb, "Failed to make oldroot rslave");
    goto on_error;
  }

  ret = umount2(".", MNT_DETACH);
  if (ret < 0) {
    ret = -1;
    mrb_sys_fail(mrb, "Failed to detach old root directory");
    goto on_error;
  }

  ret = fchdir(newroot);
  if (ret < 0) {
    ret = -1;
    mrb_sys_fail(mrb, "Failed to re-enter new root directory");
    goto on_error;
  }

  ret = 0;

on_error:
  close(oldroot);

  if (newroot >= 0)
    close(newroot);

  return ret;
}

/* TODO: This method will be implemented in mruby-pivot_root */

static mrb_value mrb_pivot_root_to(mrb_state *mrb, mrb_value self)
{
  char *newroot;
  mrb_get_args(mrb, "z", &newroot);

  if(gren_pivot_root(mrb, newroot) < 0) {
    mrb_sys_fail(mrb, "pivot_root failed!!!");
  }

  return mrb_true_value();
}

static mrb_value mrb_gren_get_ctime(mrb_state *mrb, mrb_value self)
{
  mrb_int fd;
  struct stat s;
  mrb_get_args(mrb, "i", &fd);

  if(fstat((int)fd, &s) < 0) {
    mrb_sys_fail(mrb, "fstat failed");
  }

  return mrb_fixnum_value((mrb_int)s.st_ctim.tv_sec);
}

static mrb_value mrb_gren_get_page_size(mrb_state *mrb, mrb_value self)
{
  mrb_value *page_files;
  mrb_int count;
  int i;
  off_t page_size = 0;
  mrb_get_args(mrb, "a", &page_files, &count);

  for(i = 0; i < count; i++) {
    struct stat s;
    if(stat(RSTRING_PTR(page_files[i]), &s) < 0) {
      mrb_sys_fail(mrb, "stat failed");
    }
    if(S_ISREG(s.st_mode)) {
      page_size += s.st_size;
    }
  }

  return mrb_fixnum_value((mrb_int)page_size);
}

void mrb_miehisto_gem_init(mrb_state *mrb)
{
  struct RClass *util;
  util = mrb_define_module(mrb, "MiehistoUtil");
  mrb_define_class_method(mrb, util, "pivot_root_to", mrb_pivot_root_to, MRB_ARGS_REQ(1));
  mrb_define_class_method(mrb, util, "get_ctime", mrb_gren_get_ctime, MRB_ARGS_REQ(1));
  mrb_define_class_method(mrb, util, "get_page_size", mrb_gren_get_page_size, MRB_ARGS_REQ(1));

  DONE;
}

void mrb_miehisto_gem_final(mrb_state *mrb)
{
}
