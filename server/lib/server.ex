defmodule Server do
  require Logger

  def acceptConnection(port) do
    # setting up server connnection with erlang `gen_tcp` module with the guide from https://hexdocs.pm/elixir/task-and-gen-tcp.html
    #
    # gen_tcp is an Erlang interface for TCP/IP sockets. It is used to establish a socket connection for TCP/IP layers.
    # for this implementation, am using the `listen(port, option)` function that accepts two parameters: port, and option.
    #
    # Port: is the number where our server is going to listen. By default HTTP runs on port 80, here am gonna use 2442
    # Options: is where we specify what type of connection, and rules that our server is going to accept. We can define many things, such as:
    # accepting binaries instead of texts, reading line by line, making the address reusable and also setting the state of our receiver.
    # Here we are setting up 4 things:
    #
    # 1: 'binaries': instead of receiving data as lists, we are going to accept them as binaries
    # 2: 'packet: :line': setting to receive data line by line
    # 3: 'active: false': this setting will disable our recv() function from executing until the data is fully received, and
    # 4: 'reuseaddr: true': we can reuse the address even if our listener crashes
    {:ok, server} = :gen_tcp.listen(port, [:binary, packet: :line, active: false, reuseaddr: true])
   Logger.info("Accepting connections on port #{port}")

   # we are using a private function called loop_acceptor to accept connections, and to make the server concurrent, we are setting the
   # acceptor in its own loop
   loop_acceptor(server)
  end

  # to declare private functions we use `defp` function calling

  defp loop_acceptor(server) do
    {:ok, client} = :gen_tcp.accept(server)
    # after accepting clients, we are going to serve them their request for now. for concurrency, we are also going to call a func `serve`
    serve(client)
    # we are recalling the functions so that we want to send the actual data we are getting after the doing the operation
    loop_acceptor(server)
  end

  defp serve(server) do
    # we introduce pipe operators here. more about pipe operators: https://elixirschool.com/en/lessons/basics/pipe_operator
    # but for the basics, what pipe does is evaluates the expression, and pass what's on its left hand to the right function
    # so in this case, we are going to read_line() and then pass what we read to be written in the server using write_line(server) function.
    # This is the equivalent of the: write_line(read_line(socket), socket) func. The pipe operator seems easier to read as per me.
    #
    # read_line(): is going to be a private function that is going to use gen_tcp.recv() function with parameters -> receiving the input
    # write_line(): is going to be a private function that is going to use gen_tcp.send() function with parameters -> sending it to the server
    server |> read_line() |> write_line(server)
    serve(server)
  end

  defp read_line(server) do
    {:ok, data} = :gen_tcp.recv(server, 0)
    data
  end

  defp write_line(line, server) do
    :gen_tcp.send(server, line)
  end
end
