#include "ruby.h"

VALUE method_answer42(VALUE module, VALUE self);

void Init_baz() {
  VALUE BAZ = rb_define_module("BAZ");
  rb_define_module_function(BAZ, "answer42", method_answer42, 0);
  rb_define_const(BAZ, "Hello_world", rb_str_new2("Hello World"));
}

VALUE method_answer42(VALUE module, VALUE self) {
	return INT2NUM(42);
}
