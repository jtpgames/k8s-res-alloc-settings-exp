using System.Diagnostics;
using System.Net;
using Microsoft.AspNetCore.Mvc;

namespace cpu_load_generator.Controllers;

[ApiController]
[Route("/")]
public class CpuLoadController : ControllerBase
{
    [HttpPost]
    public ActionResult ConsumeCpu(int percentage, int cores, int sleepTime)
    {
        var cts = new CancellationTokenSource();
        var state = new State(cts, percentage);

        // Start CPU load threads
        for (var i = 0; i < cores; i++)
        {
            var thread = new Thread(() => CpuKill(state))
            {
                IsBackground = true,
                Name = $"CpuLoadThread_{i}"
            };
            thread.Start();
        }

        // Schedule cancellation after sleepTime seconds
        _ = Task.Delay(TimeSpan.FromSeconds(sleepTime)).ContinueWith(_ => cts.Cancel());
        
        return new StatusCodeResult((int)HttpStatusCode.OK);
    }

    private static void CpuKill(State state)
    {
        var cpuUsage = state.Percentage;
        var cts = state.Cts;
        
        var watch = new Stopwatch();
        watch.Start();
        while (true)
        {
            if (cts.IsCancellationRequested)
            {
                break;
            }
            
            if (watch.ElapsedMilliseconds > cpuUsage)
            {
                Thread.Sleep(100 - cpuUsage);
                watch.Reset();
                watch.Start();
            }
        }
    }
}
