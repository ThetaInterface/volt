cmake_minimum_required(VERSION 3.16)

project(text_dialog LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

find_package(FLTK REQUIRED)

add_executable(text-dialog main.cpp)
target_include_directories(text-dialog PRIVATE ${FLTK_INCLUDE_DIR})
target_link_libraries(text-dialog PRIVATE ${FLTK_LIBRARIES})

if(WIN32)
    target_link_libraries(text-dialog PRIVATE shell32)
endif()
