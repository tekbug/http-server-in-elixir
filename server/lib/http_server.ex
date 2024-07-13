defmodule HttpServer do
  @moduledoc """
  A simple HTTP server implemented in Elixir using Erlang's `:gen_tcp` module to establish connections and handle client requests.
  Supports the basics of GET, POST, PUT, and DELETE methods. Just for learning purposes for now.
  By `tekbug`.
  """

  require Logger

  @doc """
  Starts the HTTP server on the given `port`.

  ## Parameters
  - `port`: The port number where the server will listen.

  ## Examples

      iex> HttpServer.start(2442)
      :ok

  """
  def start(port) do
    spawn fn ->
      case :gen_tcp.listen(port, [:binary, packet: :raw, active: false, reuseaddr: true]) do
        {:ok, socket} ->
          Logger.info("Server connected at port #{port}")
          accept_connection(socket)
        {:error, reason} ->
          Logger.error("Error occurred while connecting to the server: #{reason}")
      end
    end
  end

  defp accept_connection(socket) do
    {:ok, client} = :gen_tcp.accept(socket)
    spawn(fn -> process_request(client) end)
    accept_connection(socket)
  end

  defp process_request(client) do
    Logger.info("Processing incoming client request...")
    client
    |> receive_request()
    |> handle_request()
    |> create_response()
    |> write_response(client)
  end

  defp receive_request(client) do
    {:ok, request} = :gen_tcp.recv(client, 0)
    parse_request(request)
  end

  defp parse_request(request) do
    [req_lines | rest_lines] = String.split(request, "\r\n")  # splitting the request into two different parts: `req_lines` containing the first hand (method, path, version and stuff), and the restl_lines contains other lines
    [method, path, _] = String.split(req_lines, " ") # splitting based on the spaces after the CRLF endpoint that is found in the req_lines
    {headers, body} = parse_request_content(rest_lines) # parse the rest of the content in the request, ie the header and the body
    parsed_request = %{method: method, path: path, headers: headers, body: body}
    Logger.info("Parsed request: #{inspect(parsed_request, pretty: true)}")
    parsed_request
  end

  defp parse_request_content(lines) do
    {headers, body} = Enum.split_while(lines, fn line -> line != "" end) # split to two places as well. `header` until it founds the first empty line, and `body` everything after that empty line
    headers = Enum.into(Enum.map(headers, &parse_header/1), %{}) # then convert the key-value generated in the parse into map
    body = Enum.join(Enum.drop(body, 1), "\r\n") # join the body whenever the thing is ending with CRLF endpoint
    {headers, body}
  end

  defp parse_header(header) do
    case String.split(header, ": ", parts: 2) do # split the incoming header when it ends with : , like Content-Type: , Content-Length:
      [key, value] -> {String.downcase(key), value}
      _ -> {"invalid_header", header}
    end
  end

  defp handle_request(request) do
    case request.method do
      "GET" -> handle_get(request)
      "POST" -> handle_post(request)
      "PUT" -> handle_put(request)
      "DELETE" -> handle_delete(request)
      _ -> {404, "NOT FOUND"}
    end
  end

  defp handle_get(request) do
    case request.path do
      "/" -> {200, "We accept 200 OK now."}
      _ -> {404, "NOT FOUND"}
    end
  end

  defp handle_post(request) do
    case request.path do
      "/something" -> {201, "CREATED: #{request.body}"}
      _ -> {404, "NOT FOUND"}
    end
  end

  defp handle_put(request) do
    case request.path do
      "/update" -> {200, "Another 200 OK for #{request.body}"}
      _ -> {404, "NOT FOUND"}
    end
  end

  defp handle_delete(request) do
    case request.path do
      "/delete" -> {204, "DELETED #{request.body}"}
      _ -> {404, "NOT FOUND"}
    end
  end

  defp create_response({status, body}) do
    """
    HTTP/1.1 #{status} #{phrase(status)}\r
    Content-Type: text/html\r
    Content-Length: #{byte_size(body)}\r
    \r
    #{body}
    """
  end

  defp phrase(status) do
    %{
      200 => "OK",
      201 => "CREATED",
      204 => "NO CONTENT",
      404 => "NOT FOUND"
    }[status]
  end

  defp write_response(response, client) do
    :ok = :gen_tcp.send(client, response)
    Logger.info("Sent response: #{response}")
    :gen_tcp.close(client)
  end
end
