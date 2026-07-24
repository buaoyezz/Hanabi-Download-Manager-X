using System.Text.Json;
using Hanabi.NeoNSF;

if (args.Contains("--probe", StringComparer.OrdinalIgnoreCase))
{
    Console.WriteLine("{\"name\":\"NeoNSFX\",\"version\":\"0.1.0\",\"protocolVersion\":1,\"ready\":true}");
    return 0;
}

var protocol = new ProtocolWriter();
await using var engine = new NeoNsfEngine(protocol);

protocol.Write(writer =>
{
    writer.WriteString("type", "ready");
    writer.WriteString("name", "NeoNSFX");
    writer.WriteString("version", "0.1.0");
    writer.WriteNumber("protocolVersion", 1);
    writer.WriteStartObject("capabilities");
    writer.WriteBoolean("singleConnection", true);
    writer.WriteBoolean("multiRange", true);
    writer.WriteBoolean("unknownSizePlanning", true);
    writer.WriteNumber("maxConnectionsPerTask", 16);
    writer.WriteBoolean("pauseResume", true);
    writer.WriteBoolean("http2", true);
    writer.WriteBoolean("http3", true);
    writer.WriteBoolean("proxy", true);
    writer.WriteEndObject();
});

string? line;
while ((line = await Console.In.ReadLineAsync()) is not null)
{
    if (string.IsNullOrWhiteSpace(line))
    {
        continue;
    }

    string? requestId = null;
    try
    {
        using var document = JsonDocument.Parse(line);
        var root = document.RootElement;
        requestId = root.TryGetProperty("requestId", out var requestNode) &&
                    requestNode.ValueKind == JsonValueKind.String
            ? requestNode.GetString()
            : null;
        var command = root.GetProperty("command").GetString();
        switch (command)
        {
            case "ping":
                protocol.Response(requestId, true);
                break;
            case "enqueue":
            {
                var spec = TransferSpec.Parse(root);
                var accepted = engine.Enqueue(spec, out var error);
                protocol.Response(requestId, accepted, error);
                break;
            }
            case "pause":
            {
                var taskId = root.GetProperty("payload").GetProperty("taskId").GetString() ?? string.Empty;
                protocol.Response(requestId, engine.Pause(taskId), "Task is not active.");
                break;
            }
            case "resume":
            {
                var taskId = root.GetProperty("payload").GetProperty("taskId").GetString() ?? string.Empty;
                protocol.Response(requestId, engine.Resume(taskId), "Task is not paused.");
                break;
            }
            case "cancel":
            {
                var payload = root.GetProperty("payload");
                var taskId = payload.GetProperty("taskId").GetString() ?? string.Empty;
                var deletePartial = payload.TryGetProperty("deletePartial", out var deleteNode) &&
                                    deleteNode.ValueKind == JsonValueKind.True;
                protocol.Response(requestId, engine.Cancel(taskId, deletePartial), "Task was not found.");
                break;
            }
            case "shutdown":
                protocol.Response(requestId, true);
                return 0;
            default:
                protocol.Response(requestId, false, $"Unknown command '{command}'.");
                break;
        }
    }
    catch (Exception error)
    {
        protocol.Response(requestId, false, error.Message);
    }
}

return 0;
