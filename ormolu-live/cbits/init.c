#include "Main_stub.h"
#include <Rts.h>

__attribute__((export_name("wizer.initialize"))) void __wizer_initialize(void) {
  hs_init(NULL, NULL);
  initFixityDB();
  hs_perform_gc();
}
