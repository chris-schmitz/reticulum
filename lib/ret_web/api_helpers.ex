defmodule RetWeb.ApiHelpers do
  import Plug.Conn

  # In an API create routine, call this with a handler.
  # The handler will get passed the (validated) record and source and should return either:
  #   { :ok, { http_status, result } }
  #   { :error, [ { code, details, source } ] }
  # TODO dialyzer this
  def exec_api_create(conn, %{"records" => records}, schema, handler),
    do: process_create_records(conn, records, schema, handler)

  def exec_api_create(conn, _invalid_params, _schema, _handler) do
    conn |> send_error_resp([{:MALFORMED_REQUEST, "Missing 'records' property in request.", nil}])
  end

  defp process_create_records(conn, record, schema, handler) when is_map(record) do
    case ExJsonSchema.Validator.validate(schema, record, error_formatter: Ret.JsonSchemaApiErrorFormatter) do
      :ok ->
        case handler.(record, "records") do
          {:ok, {status, result}} ->
            conn |> send_resp(status, %{"records" => result} |> Poison.encode!())

          {:error, errors} ->
            conn |> send_error_resp(errors)
        end

      {:error, errors} ->
        conn
        |> send_error_resp(
          Enum.map(errors, fn {code, detail, source} -> {code, detail, source |> String.replace(~r/^#/, "records")} end)
        )
    end
  end

  defp process_create_records(conn, records, schema, handler) when is_list(records) do
    results =
      records
      |> Enum.with_index()
      |> Enum.map(fn {record, index} ->
        case ExJsonSchema.Validator.validate(schema, record, error_formatter: Ret.JsonSchemaApiErrorFormatter) do
          :ok ->
            case handler.(record, "records[#{index}]") do
              {:ok, {status, result}} ->
                %{status: status, body: %{"records" => result}}

              {:error, errors} ->
                %{status: 400, body: to_error_multi_request_response(errors)}
            end

          {:error, errors} ->
            %{
              status: 400,
              body:
                to_error_multi_request_response(
                  Enum.map(errors, fn {code, detail, source} ->
                    {code, detail, source |> String.replace(~r/^#/, "records[#{index}]")}
                  end)
                )
            }
        end
      end)

    conn |> send_resp(207, results |> Poison.encode!())
  end

  defp process_create_records(conn, _record, _schema, _handler) do
    conn
    |> send_error_resp([{:MALFORMED_RECORD, "Malformed record in 'records' property.", "records"}])
  end

  defp send_error_resp(conn, [{:RECORD_EXISTS, _detail, _source}] = errors), do: conn |> send_error_resp(409, errors)
  defp send_error_resp(conn, errors), do: send_error_resp(conn, 400, errors)

  defp send_error_resp(conn, status, errors) do
    conn
    |> send_resp(
      status,
      %{errors: Enum.map(errors, fn {code, detail, source} -> %{code: code, detail: detail, source: source} end)}
      |> Poison.encode!()
    )
  end

  defp to_error_multi_request_response(errors) do
    %{errors: Enum.map(errors, fn {code, detail, source} -> %{code: code, detail: detail, source: source} end)}
  end
end