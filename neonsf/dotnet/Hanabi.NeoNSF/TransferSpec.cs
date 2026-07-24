using System.Text.Json;

namespace Hanabi.NeoNSF;

internal sealed record ProxySpec(
    bool Enabled,
    string Type,
    string Host,
    int Port,
    string? Username,
    string? Password);

internal sealed record TransferSpec(
    string TaskId,
    string Url,
    string FilePath,
    IReadOnlyDictionary<string, string> Headers,
    long? ExpectedSize,
    int MaxRetries,
    int MaxConnections,
    int ConnectionTimeoutSeconds,
    int ReadTimeoutSeconds,
    string HttpVersionPolicy,
    bool AllowInsecureTls,
    string? ExpectedETag,
    string? ExpectedLastModified,
    bool UseSystemProxy,
    ProxySpec? Proxy)
{
    public static TransferSpec Parse(JsonElement command)
    {
        var payload = command.GetProperty("payload");
        var taskId = RequiredString(payload, "taskId");
        var url = RequiredString(payload, "url");
        var filePath = RequiredString(payload, "filePath");
        if (!Uri.TryCreate(url, UriKind.Absolute, out var uri) ||
            (uri.Scheme != Uri.UriSchemeHttp && uri.Scheme != Uri.UriSchemeHttps))
        {
            throw new ArgumentException("NeoNSFX only accepts absolute HTTP/HTTPS URLs.");
        }

        var headers = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        if (payload.TryGetProperty("headers", out var headerNode) &&
            headerNode.ValueKind == JsonValueKind.Object)
        {
            foreach (var property in headerNode.EnumerateObject())
            {
                if (property.Value.ValueKind == JsonValueKind.String)
                {
                    headers[property.Name] = property.Value.GetString() ?? string.Empty;
                }
            }
        }

        ProxySpec? proxy = null;
        var useSystemProxy = false;
        if (payload.TryGetProperty("proxy", out var proxyNode) &&
            proxyNode.ValueKind == JsonValueKind.Object &&
            OptionalBool(proxyNode, "enabled", false))
        {
            var proxyType = OptionalString(proxyNode, "type", "system");
            if (proxyType.Equals("system", StringComparison.OrdinalIgnoreCase))
            {
                useSystemProxy = true;
            }
            else
            {
                proxy = new ProxySpec(
                    true,
                    proxyType,
                    RequiredString(proxyNode, "host"),
                    OptionalInt(proxyNode, "port", 8080),
                    OptionalNullableString(proxyNode, "username"),
                    OptionalNullableString(proxyNode, "password"));
            }
        }

        return new TransferSpec(
            taskId,
            url,
            filePath,
            headers,
            OptionalLong(payload, "expectedSize"),
            Math.Clamp(OptionalInt(payload, "maxRetries", 3), 0, 10),
            Math.Clamp(OptionalInt(payload, "maxConnections", 8), 1, 16),
            Math.Clamp(OptionalInt(payload, "connectionTimeoutSeconds", 15), 3, 120),
            Math.Clamp(OptionalInt(payload, "readTimeoutSeconds", 30), 5, 300),
            OptionalString(payload, "httpVersionPolicy", "auto"),
            OptionalBool(payload, "allowInsecureTls", false),
            OptionalNullableString(payload, "expectedETag"),
            OptionalNullableString(payload, "expectedLastModified"),
            useSystemProxy,
            proxy);
    }

    private static string RequiredString(JsonElement node, string name)
    {
        if (!node.TryGetProperty(name, out var value) || value.ValueKind != JsonValueKind.String)
        {
            throw new ArgumentException($"Missing required string '{name}'.");
        }
        var result = value.GetString()?.Trim() ?? string.Empty;
        if (result.Length == 0)
        {
            throw new ArgumentException($"'{name}' cannot be empty.");
        }
        return result;
    }

    private static string OptionalString(JsonElement node, string name, string fallback) =>
        node.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.String
            ? value.GetString() ?? fallback
            : fallback;

    private static string? OptionalNullableString(JsonElement node, string name) =>
        node.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.String
            ? value.GetString()
            : null;

    private static int OptionalInt(JsonElement node, string name, int fallback) =>
        node.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.Number && value.TryGetInt32(out var result)
            ? result
            : fallback;

    private static long? OptionalLong(JsonElement node, string name) =>
        node.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.Number && value.TryGetInt64(out var result) && result > 0
            ? result
            : null;

    private static bool OptionalBool(JsonElement node, string name, bool fallback) =>
        node.TryGetProperty(name, out var value) &&
        (value.ValueKind == JsonValueKind.True || value.ValueKind == JsonValueKind.False)
            ? value.GetBoolean()
            : fallback;
}
