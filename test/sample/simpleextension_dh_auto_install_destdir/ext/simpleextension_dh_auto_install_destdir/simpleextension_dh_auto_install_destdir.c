#include "ruby.h"

VALUE method_answer42(VALUE module, VALUE self);

void Init_simpleextension() {
  VALUE SimpleExtension = rb_define_module("SimpleExtension");
  rb_define_module_function(SimpleExtension, "answer42", method_answer42, 0);
  rb_define_const(SimpleExtension, "Hello_world", rb_str_new2("Hello World"));
}

VALUE method_answer42(VALUE module, VALUE self) {
	return INT2NUM(42);
}
