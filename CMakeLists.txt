cmake_minimum_required(VERSION 3.20)
project(Secret_of_ManaRecomp C)
set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_C_EXTENSIONS OFF)
# The framework lives INSIDE this project (secret-of-mana-recomp/snesrecomp),
# so the whole tree is self-contained: no external checkout, no drift between
# the sources that were edited and the sources that get compiled.
set(SNESRECOMP_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/snesrecomp" CACHE PATH "Path to pinned snesrecomp checkout")
set(RECOMP_UI_ROOT "${SNESRECOMP_ROOT}/recomp-ui" CACHE PATH "Path to pinned recomp-ui checkout")
option(SOM_ENABLE_DEBUG_COVERAGE "Expose the optional coverage capture toggle in the launcher" ON)
# Always on: the game ships a mod catalog (mods/preloaded/packages).
set(SNESRECOMP_ENABLE_MODS ON CACHE BOOL
  "Enable the launcher's Mods page for this game" FORCE)
set(SNESRECOMP_EXPOSE_COVERAGE_MOD "${SOM_ENABLE_DEBUG_COVERAGE}" CACHE BOOL
  "Show the default-off Coverage Capture launcher option" FORCE)
# Keep the PPU/DMA forensic history in diagnostic builds so a graphics report
# includes the SNES mode, enabled background layers, VRAM/CGRAM occupancy, and
# graphics DMA activity from the same session. It is intentionally absent from
# builds that disable this project's developer diagnostics.
set(SNESRECOMP_ENABLE_PPU_DMA_HISTORY "${SOM_ENABLE_DEBUG_COVERAGE}" CACHE BOOL
  "Capture diagnostic PPU snapshots and DMA event history" FORCE)
if(NOT EXISTS "${SNESRECOMP_ROOT}/runner/runner.cmake")
  message(FATAL_ERROR "SNESRecomp not found at ${SNESRECOMP_ROOT}; pass -DSNESRECOMP_ROOT=<checkout>")
endif()
if(NOT EXISTS "${RECOMP_UI_ROOT}/recomp_ui.cmake")
  message(FATAL_ERROR "recomp-ui not found at ${RECOMP_UI_ROOT}; pass -DRECOMP_UI_ROOT=<checkout>")
endif()
include(${SNESRECOMP_ROOT}/runner/runner.cmake)
file(GLOB GENERATED_SOURCES CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/generated/*.c")
set(SOM_COMMON_RUNNER_SOURCES ${SNESRECOMP_RUNNER_SOURCES})
set(SOM_SOURCES src/som_spc_player.c src/som_frame_driver.c src/som_cheats.c src/som_title_data.c)
set(SOM_HEADLESS_RUNNER_SOURCES ${SOM_COMMON_RUNNER_SOURCES})
list(REMOVE_ITEM SOM_HEADLESS_RUNNER_SOURCES
  "${SNESRECOMP_RUNNER_ROOT}/src/diagnostics/replay_writer.c"
  "${SNESRECOMP_RUNNER_ROOT}/src/diagnostics/trace_writer.c"
  "${SNESRECOMP_RUNNER_ROOT}/src/keybinds.c"
  "${SNESRECOMP_RUNNER_ROOT}/src/snes_savestate_menu.c"
  "${SNESRECOMP_RUNNER_ROOT}/src/snes_osd.c"
  "${SNESRECOMP_RUNNER_ROOT}/src/host_report.c")
add_executable(som_headless ${SOM_HEADLESS_RUNNER_SOURCES} ${GENERATED_SOURCES} ${SOM_SOURCES} src/som_headless_main.c)
target_include_directories(som_headless PRIVATE config generated "${SNESRECOMP_RUNNER_ROOT}/src" "${SNESRECOMP_RUNNER_ROOT}/src/snes")
set(SNESRECOMP_SDL3_FETCH ON CACHE BOOL "Fetch SDL3 from source if not found")
set(SNESRECOMP_SDL_BACKEND SDL3 CACHE STRING "Desktop SDL backend")
set(SOM_DESKTOP_RUNNER_SOURCES ${SOM_COMMON_RUNNER_SOURCES}
  "${SNESRECOMP_RUNNER_ROOT}/src/diagnostics/replay_writer.c"
  "${SNESRECOMP_RUNNER_ROOT}/src/diagnostics/trace_writer.c"
  "${SNESRECOMP_RUNNER_ROOT}/src/keybinds.c"
  "${SNESRECOMP_RUNNER_ROOT}/src/snes_savestate_menu.c"
  "${SNESRECOMP_RUNNER_ROOT}/src/snes_osd.c"
  "${SNESRECOMP_RUNNER_ROOT}/src/host_report.c")
add_executable(som_recomp ${SOM_DESKTOP_RUNNER_SOURCES} ${GENERATED_SOURCES} ${SOM_SOURCES} src/som_main.c)
target_include_directories(som_recomp PRIVATE config generated "${SNESRECOMP_RUNNER_ROOT}/src" "${SNESRECOMP_RUNNER_ROOT}/src/snes")
foreach(_target som_headless som_recomp)
  if(MSVC)
    target_compile_options(${_target} PRIVATE /W4 /MP)
    target_compile_definitions(${_target} PRIVATE _CRT_SECURE_NO_WARNINGS)
  else()
    target_compile_options(${_target} PRIVATE -Wall -Wextra -Wpedantic)
  endif()
endforeach()
if(MSVC)
  set_source_files_properties(${SOM_COMMON_RUNNER_SOURCES} ${SOM_DESKTOP_RUNNER_SOURCES} PROPERTIES COMPILE_FLAGS /W0)
endif()
snesrecomp_target_sdl(som_recomp)
include(${RECOMP_UI_ROOT}/recomp_ui.cmake)
recomp_target_launcher_ui(som_recomp CONSOLE snes BOXART "${CMAKE_CURRENT_SOURCE_DIR}/assets/boxart.tga")
snesrecomp_target_desktop_host(som_recomp)
snesrecomp_target_mod_catalog(som_recomp "${CMAKE_CURRENT_SOURCE_DIR}/mods/preloaded")
if(WIN32)
  target_link_libraries(som_headless PRIVATE kernel32 user32 gdi32 winmm)
  target_link_libraries(som_recomp PRIVATE kernel32 user32 gdi32 winmm)
endif()
message(STATUS "Secret of Mana targets: som_headless, som_recomp")
message(STATUS "SNESRecomp: ${SNESRECOMP_ROOT}")
message(STATUS "recomp-ui: ${RECOMP_UI_ROOT}")

