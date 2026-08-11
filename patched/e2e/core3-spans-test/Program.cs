using System;
using System.Diagnostics;
using System.Linq;
using System.Net.Http;
using System.Threading;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Hosting.Server;
using Microsoft.AspNetCore.Hosting.Server.Features;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

namespace TestApplication.Core3
{
    public class Program
    {
        private static readonly ActivitySource AppActivitySource =
            new ActivitySource("TestApp.Core3", "1.0.0");

        public static void Main(string[] args)
        {
            // Start a Kestrel web server on a random port
            using var host = CreateHostBuilder(args).Build();
            host.Start();

            // Discover the address Kestrel bound to
            var server = (IServer)host.Services.GetService(typeof(IServer));
            var addressFeature = server.Features.Get<IServerAddressesFeature>();
            var address = addressFeature.Addresses.First();

            Console.WriteLine($"Server listening on {address}");

            // Make HTTP calls to ourselves — auto-instrumentation will produce
            // HTTP Client spans, ASP.NET Core Server spans, and our manual spans.
            using var httpClient = new HttpClient();

            // 1) GET /test — creates server span + manual child span
            var response = httpClient.GetAsync($"{address}/test").Result;
            Console.WriteLine($"GET /test => {(int)response.StatusCode}");

            // 2) GET /health — simple endpoint, no manual span
            response = httpClient.GetAsync($"{address}/health").Result;
            Console.WriteLine($"GET /health => {(int)response.StatusCode}");

            // Give the console exporter a moment to flush
            Thread.Sleep(2000);
            Console.WriteLine("Application completed successfully.");
        }

        public static IHostBuilder CreateHostBuilder(string[] args) =>
            Host.CreateDefaultBuilder(args)
                .ConfigureWebHostDefaults(webBuilder =>
                {
                    webBuilder
                        .UseUrls("http://127.0.0.1:0")
                        .Configure(app =>
                        {
                            app.UseRouting();
                            app.UseEndpoints(endpoints =>
                            {
                                // /test — creates a manual child span inside the
                                // auto-instrumented ASP.NET Core server span
                                endpoints.MapGet("/test", async context =>
                                {
                                    using (var activity = AppActivitySource.StartActivity(
                                        "ManualServerWork",
                                        ActivityKind.Internal))
                                    {
                                        activity?.SetTag("test.key", "test.value");
                                        activity?.SetTag("test.framework", "netcoreapp3.1");

                                        // Simulate a tiny bit of work
                                        Thread.Sleep(50);
                                    }

                                    await context.Response.WriteAsync("OK");
                                });

                                // /health — plain endpoint, no manual span
                                endpoints.MapGet("/health", async context =>
                                {
                                    await context.Response.WriteAsync("Healthy");
                                });
                            });
                        });
                });
    }
}
