#include <iostream>

#include <spdlog/spdlog.h>

#include <ranges>
#include <string_view>

#undef ASIO_NO_DEPRECATED

#include <asio.hpp>
#include <asio/ts/buffer.hpp>
#include <asio/ts/internet.hpp>

#include <thread>

// This file will be generated automatically when cur_you run the CMake
// configuration step. It creates a namespace called `networking`. You can modify
// the source template at `configured_files/config.hpp.in`.
#include <internal_use_only/config.hpp>

constexpr auto port_nr = 80;

constexpr std::string_view html_req =
  "GET /index.html HTTP/1.1\r\n"
  "Host: example.com\r\n"
  "Connection: close\r\n\r\n";

// constexpr auto ip_addr = "212.77.98.9";
constexpr auto ip_addr = "93.184.216.34";

std::vector<char> vBuffer(20 * 1024);

void grab_some_data(asio::ip::tcp::socket &socket)
{

  auto read_handler = [&](const asio::error_code &error, std::size_t bytes_transferred) {
    if (!error) {
      for (std::size_t i = 0; i < bytes_transferred; i++) { fmt::print("{}", vBuffer[i]); }
      grab_some_data(socket);
    }
  };

  socket.async_read_some(asio::buffer(vBuffer.data(), vBuffer.size()), read_handler);
}


int main()
{

  try {

    fmt::print("{}\n", networking::cmake::git_sha);

    vBuffer.resize(20 * 1024);

    asio::error_code ec;

    // create context
    asio::io_context context;

    asio::io_context::work idleWork(context);

    std::thread thread_context = std::thread([&]() { context.run(); });

    // adress of the real endpoint
    asio::ip::tcp::endpoint endpoint{ asio::ip::make_address(ip_addr, ec), port_nr };

    // create socker
    asio::ip::tcp::socket socket(context);

    // connect to socket
    socket.connect(endpoint, ec);

    if (!ec) {
      fmt::print("Connected!!!\n");
    } else {
      fmt::print("Fail: {}\n", ec.message());
    }

    if (socket.is_open()) {

      // prime asio context to read data
      grab_some_data(socket);

      // read some data
      socket.write_some(asio::buffer(html_req.data(), html_req.size()), ec);

      // socket.wait(socket.wait_read);
      // std::size_t bytes = socket.available();

      fmt::print("html_req: {}, ec: {} \n", html_req, ec.message());

      // if (bytes > 0) {
      //   std::vector<char> vBuffer(bytes);
      //   socket.read_some(asio::buffer(vBuffer.data(), vBuffer.size()), ec);

      //   for (const auto &byte : vBuffer) { fmt::print("{}", byte); }
      // }

      using namespace std::chrono_literals;
      std::this_thread::sleep_for(200000ms);
    }
  } catch (std::exception &e) {
    fmt::print("EXCEPTION: {}", e.what());
  }
  return 0;
}

