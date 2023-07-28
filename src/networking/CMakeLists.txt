add_executable(networking main.cpp)

target_link_libraries(
  networking
  PRIVATE networking::networking_options
          networking::networking_warnings)

target_link_system_libraries(
  networking
  PRIVATE
          fmt::fmt
          spdlog::spdlog
          asio::asio
          )

target_include_directories(networking PRIVATE "${CMAKE_BINARY_DIR}/configured_files/include")
