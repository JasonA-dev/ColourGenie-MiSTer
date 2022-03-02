OPTIMIZE="-O3 --x-assign fast --x-initial fast --noassert"
WARNINGS="-Wno-fatal"
DEFINES="+define+SIMULATION=1 "
echo "verilator -cc --compiler msvc $WARNINGS $OPTIMIZE"
verilator -cc --compiler msvc $WARNINGS $OPTIMIZE \
--converge-limit 6000 \
--top-module emu sim.v \
-I../rtl \
-I../rtl/tv80 \
-I../src
