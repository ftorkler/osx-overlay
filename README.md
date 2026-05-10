## Build & Run

cmake -B cmake-build-debug -G Ninja
cmake --build cmake-build-debug
./cmake-build-debug/osx-overlay-debug

cmake -DCMAKE_BUILD_TYPE=Release -B cmake-build-release -G Ninja
cmake --build cmake-build-release
./cmake-build-debug/osx-overlay
