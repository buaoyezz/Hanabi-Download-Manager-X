using System.Collections.Concurrent;
using System.Net;

namespace Hanabi.NeoNSF;

internal sealed class HttpClientPool : IDisposable
{
    private readonly ConcurrentDictionary<ClientKey, HttpClient> _clients = new();

    public HttpClient Get(TransferSpec spec)
    {
        var proxy = spec.Proxy;
        var key = new ClientKey(
            spec.AllowInsecureTls,
            spec.ConnectionTimeoutSeconds,
            spec.UseSystemProxy,
            proxy?.Type ?? string.Empty,
            proxy?.Host ?? string.Empty,
            proxy?.Port ?? 0,
            proxy?.Username ?? string.Empty,
            proxy?.Password ?? string.Empty);
        return _clients.GetOrAdd(key, CreateClient);
    }

    private static HttpClient CreateClient(ClientKey key)
    {
        var handler = new SocketsHttpHandler
        {
            AllowAutoRedirect = true,
            AutomaticDecompression = DecompressionMethods.None,
            ConnectTimeout = TimeSpan.FromSeconds(key.ConnectionTimeoutSeconds),
            EnableMultipleHttp2Connections = true,
            MaxConnectionsPerServer = 128,
            PooledConnectionIdleTimeout = TimeSpan.FromSeconds(90),
            PooledConnectionLifetime = TimeSpan.FromMinutes(10),
            UseCookies = false,
            UseProxy = key.UseSystemProxy || !string.IsNullOrWhiteSpace(key.ProxyHost),
        };

        if (key.AllowInsecureTls)
        {
            handler.SslOptions.RemoteCertificateValidationCallback = static (_, _, _, _) => true;
        }

        if (!string.IsNullOrWhiteSpace(key.ProxyHost))
        {
            var scheme = key.ProxyType.ToLowerInvariant() switch
            {
                "socks5" => "socks5",
                "socks4" => "socks4",
                "https" => "https",
                _ => "http",
            };
            var webProxy = new WebProxy(new Uri($"{scheme}://{key.ProxyHost}:{key.ProxyPort}"));
            if (!string.IsNullOrWhiteSpace(key.ProxyUsername))
            {
                webProxy.Credentials = new NetworkCredential(key.ProxyUsername, key.ProxyPassword);
            }
            handler.Proxy = webProxy;
        }

        return new HttpClient(handler, disposeHandler: true)
        {
            Timeout = Timeout.InfiniteTimeSpan,
        };
    }

    public void Dispose()
    {
        foreach (var client in _clients.Values)
        {
            client.Dispose();
        }
        _clients.Clear();
    }

    private sealed record ClientKey(
        bool AllowInsecureTls,
        int ConnectionTimeoutSeconds,
        bool UseSystemProxy,
        string ProxyType,
        string ProxyHost,
        int ProxyPort,
        string ProxyUsername,
        string ProxyPassword);
}
