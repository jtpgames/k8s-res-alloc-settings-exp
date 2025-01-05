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

        for (var i = 0; i < cores; i++)
        {
            ThreadPool.QueueUserWorkItem(CpuKill, state);
        }
        
        Thread.Sleep(sleepTime);
        cts.Cancel();
        
        return new StatusCodeResult((int)HttpStatusCode.OK);
    }

    private static void CpuKill(object stateObj)
    {
        var state = (State)stateObj;
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
