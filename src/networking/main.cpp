#include <iostream>

#include <spdlog/spdlog.h>

#include <string_view>
#include <ranges>

#include <asio.hpp>
#include <asio/ts/buffer.hpp>
#include <asio/ts/internet.hpp>


// This file will be generated automatically when cur_you run the CMake
// configuration step. It creates a namespace called `networking`. You can modify
// the source template at `configured_files/config.hpp.in`.
#include <internal_use_only/config.hpp>

constexpr auto port_nr = 80;

constexpr std::string_view html_req = "GET /index.html HTTP/1.1\r\n"
                                      "Host: example.com\r\n"
                                      "Connection: close\r\n\r\n";

int main()
{
  fmt::print("{}\n", networking::cmake::git_sha);

  asio::error_code ec;

  // create context
  asio::io_context context;

  // adress of the real endpoint
  asio::ip::tcp::endpoint endpoint{ asio::ip::make_address("93.184.216.34", ec), port_nr };

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
    // read some data
    socket.write_some(asio::buffer(html_req.data(), html_req.size()), ec);

    
    std::size_t bytes = socket.available();

    fmt::print("html_req: {}, ec: {}", html_req, ec.message());

    if (bytes > 0) {
      std::vector<char> vBuffer(bytes);
      socket.read_some(asio::buffer(vBuffer.data(), vBuffer.size()), ec);

      for (const auto &byte : vBuffer) { fmt::print("byte: {}", byte); }
    }
  }

  return 0;
}