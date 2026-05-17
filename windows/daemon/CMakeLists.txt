cmake_minimum_required(VERSION 3.14)

add_executable(HanabiDaemon WIN32 main.cpp)

target_compile_features(HanabiDaemon PUBLIC cxx_std_17)
target_compile_definitions(HanabiDaemon PRIVATE UNICODE _UNICODE)

if(MSVC)
  target_compile_options(HanabiDaemon PRIVATE /utf-8)
endif()

target_link_libraries(HanabiDaemon PRIVATE user32 shell32 comctl32)
