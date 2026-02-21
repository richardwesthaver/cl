#!/bin/sh
cd ..

CL_HOME=obj/cl-home/ ./src/runtime/cl --noinform --core output/cl.core --disable-debugger --eval '(print (require :asdf))' --disable-debugger --eval '(quit)'
./install.sh --prefix=/tmp/test-cl-install > /dev/null

/tmp/test-cl-install/bin/cl --noinform --disable-debugger --eval '(print (require :asdf))' --disable-debugger --eval '(quit)'
(cd /tmp/test-cl-install/bin/; ./cl --noinform --disable-debugger --eval '(print (require :asdf))' --disable-debugger --eval '(quit)')
PATH=/tmp/test-cl-install/bin cl --noinform --disable-debugger --eval '(print (require :asdf))' --disable-debugger --eval '(quit)'

/tmp/test-cl-install/bin/cl --noinform --core /tmp/test-cl-install/lib/cl/cl.core --disable-debugger --eval '(print (require :asdf))' --disable-debugger --eval '(quit)'
PATH=/tmp/test-cl-install/bin cl --noinform --core /tmp/test-cl-install/lib/cl/cl.core --disable-debugger --eval '(print (require :asdf))' --disable-debugger --eval '(quit)'
(cd /tmp/test-cl-install/bin; ./cl --noinform --core /tmp/test-cl-install/lib/cl/cl.core --disable-debugger --eval '(print (require :asdf))' --disable-debugger --eval '(quit)')

cd /tmp/test-cl-install/
ln -s bin/cl sym-cl
./sym-cl --noinform --disable-debugger --eval '(print (require :asdf))' --disable-debugger --eval '(quit)'
./sym-cl --noinform --core /tmp/test-cl-install/lib/cl/cl.core --disable-debugger --eval '(print (require :asdf))' --disable-debugger --eval '(quit)'

mv bin/cl .
ln -s /tmp/test-cl-install/cl ./bin/cl
./bin/cl --noinform --disable-debugger --eval '(print (require :asdf))' --disable-debugger --eval '(quit)'

mv lib/cl/cl.core lib/cl/contrib .
./cl --noinform --disable-debugger --eval '(print (require :asdf))' --disable-debugger --eval '(quit)'
PATH=. cl --noinform --disable-debugger --eval '(print (require :asdf))' --disable-debugger --eval '(quit)'
./cl --noinform --core cl.core --disable-debugger --eval '(print (require :asdf))' --disable-debugger --eval '(quit)'
PATH=. cl --noinform --core cl.core --disable-debugger --eval '(print (require :asdf))' --disable-debugger --eval '(quit)'

rm -r /tmp/test-cl-install
