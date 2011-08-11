#include "ruby.h"

VALUE method_answer42(VALUE module, VALUE self);

void Init_name_clash() {
  VALUE NameClash= rb_define_module("NameClash");
  rb_define_module_function(NameClash, "answer42", method_answer42, 0);
  rb_define_const(NameClash, "Hello_world", rb_str_new2("Hello World"));
}

VALUE method_answer42(VALUE module, VALUE self) {
  VALUE answer = rb_const_get(module, rb_intern("ANSWER_42"));
	return answer;
}
