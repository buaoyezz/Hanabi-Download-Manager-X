using System.Text;
using System.Text.Json;

namespace Hanabi.NeoNSF;

internal sealed class ProtocolWriter
{
    private readonly object _gate = new();

    public void Write(Action<Utf8JsonWriter> payload)
    {
        using var stream = new MemoryStream();
        using (var writer = new Utf8JsonWriter(stream))
        {
            writer.WriteStartObject();
            payload(writer);
            writer.WriteEndObject();
        }

        var line = Encoding.UTF8.GetString(stream.ToArray());
        lock (_gate)
        {
            Console.Out.WriteLine(line);
            Console.Out.Flush();
        }
    }

    public void Response(string? requestId, bool ok, string? error = null)
    {
        Write(writer =>
        {
            writer.WriteString("type", "response");
            if (!string.IsNullOrWhiteSpace(requestId))
            {
                writer.WriteString("requestId", requestId);
            }
            writer.WriteBoolean("ok", ok);
            if (!string.IsNullOrWhiteSpace(error))
            {
                writer.WriteString("error", error);
            }
        });
    }
}
