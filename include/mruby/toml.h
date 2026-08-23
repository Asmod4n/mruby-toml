#ifndef MRUBY_TOML_H
#define MRUBY_TOML_H

#include <mruby.h>

MRB_BEGIN_DECL

#define E_TOML_ERROR(mrb) \
  (mrb_class_get_under(mrb, mrb_module_get(mrb, "TOML"), "Error"))
#define E_TOML_PARSE_ERROR(mrb) \
  (mrb_class_get_under(mrb, mrb_module_get(mrb, "TOML"), "ParseError"))
#define E_TOML_SYNTAX_ERROR(mrb) \
  (mrb_class_get_under(mrb, mrb_module_get(mrb, "TOML"), "SyntaxError"))
#define E_TOML_TYPE_ERROR(mrb) \
  (mrb_class_get_under(mrb, mrb_module_get(mrb, "TOML"), "TypeError"))

MRB_END_DECL

#endif
