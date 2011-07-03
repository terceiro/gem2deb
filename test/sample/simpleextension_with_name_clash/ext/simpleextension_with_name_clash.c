#include "ruby.h"

VALUE method_answer42(VALUE module, VALUE self);

void Init_simpleextension_with_name_clash() {
  VALUE SimpleExtensionWithNameClass = rb_define_module("SimpleExtensionWithNameClash");
  rb_define_module_function(SimpleExtensionWithNameClass, "answer42", method_answer42, 0);
  rb_define_const(SimpleExtensionWithNameClass, "Hello_world", rb_str_new2("Hello World"));
}

VALUE method_answer42(VALUE module, VALUE self) {
  VALUE answer = rb_const_get(module, rb_intern("ANSWER_42"));
	return answer;
}
